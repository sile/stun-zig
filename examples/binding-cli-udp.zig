const std = @import("std");
const net = std.net;
const os = std.os;
const stun = @import("../src/stun.zig");
const allocator = std.heap.page_allocator;

pub fn main() !void {
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);
    if (args.len != 3) {
        std.debug.print("Usage: \n$ binding-cli-udp SERVER_ADDR PORT\n\n", .{});
        return error.InvalidCommandLineArg;
    }

    const port = try std.fmt.parseInt(u16, args[2], 10);
    const server_addr = try net.Address.parseIp4(args[1], port);
    const client_addr = net.Address.initIp4(.{ 0, 0, 0, 0 }, 0);

    const socket = try os.socket(
        server_addr.any.family,
        os.SOCK.DGRAM,
        os.IPPROTO.UDP,
    );
    defer {
        os.closeSocket(socket);
    }
    try os.bind(socket, &client_addr.any, client_addr.getOsSockLen());

    // Send.
    const MessageType = stun.Message(stun.rfc5389.Attribute);
    const request: MessageType = .{
        .class = stun.Class.request,
        .method = stun.rfc5389.methods.binding,
        .transaction_id = try generateTransationId(),
        .attributes = &.{},
    };

    var buf: [4096]u8 = undefined;
    {
        var stream = std.io.fixedBufferStream(&buf);
        try request.encode(stream.writer());
        const sent_len = try os.sendto(
            socket,
            stream.getWritten(),
            0,
            &server_addr.any,
            server_addr.getOsSockLen(),
        );
        if (sent_len != try stream.getPos()) {
            return error.TooFewSentBytes;
        }
    }

    // Recv.
    var recv_addr = server_addr;
    const recv_len = try os.recvfrom(socket, &buf, 0, &recv_addr.any, &recv_addr.getOsSockLen());
    if (!recv_addr.eql(server_addr)) {
        return error.RecvFromUnexpectedAddress;
    }
    {
        var stream = std.io.fixedBufferStream(buf[0..recv_len]);
        const response = try MessageType.decode(allocator, stream.reader());

        std.debug.print("Binding response from {s}\n", .{recv_addr});
        std.debug.print("- class: {s}\n", .{response.class});
        std.debug.print("- method: {d}\n", .{response.method});
        std.debug.print("- transaction_id: {any}\n", .{response.transaction_id});
        std.debug.print("- attributes: \n", .{});
        for (response.attributes) |attr| {
            std.debug.print("  - {any}\n", .{attr.attr});
        }
    }
}

fn generateTransationId() !stun.TransactionId {
    var buf: stun.TransactionId = undefined;
    try os.getrandom(&buf);
    return buf;
}
