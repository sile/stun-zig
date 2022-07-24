const std = @import("std");
const net = std.net;
const mem = std.mem;
const os = std.os;
const stun = @import("../src/stun.zig");
const allocator = std.heap.page_allocator;

pub const io_mode = .evented;

pub fn main() !void {
    var cpu: u64 = try std.Thread.getCpuCount();
    var promises =
        try std.heap.page_allocator.alloc(@Frame(worker), cpu);
    defer std.heap.page_allocator.free(promises);

    while (cpu > 0) : (cpu -= 1) {
        promises[cpu - 1] = async worker();
    }

    for (promises) |*future| {
        try await future;
    }
}

fn worker() !void {
    std.event.Loop.startCpuBoundOperation();

    // Bind.
    const bind_addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, 3478);
    const socket = try os.socket(
        bind_addr.any.family,
        os.SOCK.DGRAM,
        os.IPPROTO.UDP,
    );
    defer os.closeSocket(socket);

    try std.os.setsockopt(socket, os.SOL.SOCKET, os.SO.REUSEADDR, &mem.toBytes(@as(c_int, 1)));
    try std.os.setsockopt(socket, os.SOL.SOCKET, os.SO.REUSEPORT, &mem.toBytes(@as(c_int, 1)));
    try os.bind(socket, &bind_addr.any, bind_addr.getOsSockLen());

    var buf: [1200]u8 = undefined;
    while (true) {
        // Recv.
        var transaction_id: stun.TransactionId = undefined;
        var recv_addr: net.Address = bind_addr;
        const recv_len = try os.recvfrom(socket, &buf, 0, &recv_addr.any, &recv_addr.getOsSockLen());

        var reader = std.io.fixedBufferStream(buf[0..recv_len]).reader();
        const request = try stun.Message(stun.RawAttribute).decode(allocator, reader);
        if (request.class != stun.Class.request) {
            return error.OnlyBindingRequestIsSupported;
        }
        if (request.method != stun.rfc5389.methods.binding) {
            return error.OnlyBindingRequestIsSupported;
        }

        transaction_id = request.transaction_id;

        // Send.
        const xor_addr = stun.net.xorAddress(recv_addr, transaction_id);
        const response: stun.Message(stun.rfc5389.attributes.XorMappedAddress) = .{
            .class = stun.Class.success_response,
            .method = stun.rfc5389.methods.binding,
            .transaction_id = transaction_id,
            .attributes = &[_]stun.rfc5389.attributes.XorMappedAddress{
                stun.rfc5389.attributes.XorMappedAddress{ .xor_addr = xor_addr },
            },
        };
        var stream = std.io.fixedBufferStream(&buf);
        try response.encode(stream.writer());
        const sent_len = try os.sendto(
            socket,
            stream.getWritten(),
            0,
            &recv_addr.any,
            recv_addr.getOsSockLen(),
        );
        if (sent_len != try stream.getPos()) {
            return error.TooFewSentBytes;
        }
    }
}
