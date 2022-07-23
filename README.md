stun-zig
========

Zig implementation of STUN protocol ([RFC 5389]).

[RFC 5389]: https://datatracker.ietf.org/doc/html/rfc5389

Zig version
-----------

v0.9.1

Examples
--------

Run UDP STUN (BIDNING) server:
```console
$ zig run examples/binding-srv-udp.zig --main-pkg-path ../
```

RUN UDP STUN (BINDING) client:
```console
$ zig run examples/binding-cli-udp.zig --main-pkg-path ../ -- 127.0.0.1 3478
Binding response from 127.0.0.1:3478
- class: Class.success_response
- method: 1
- transaction_id: { 153, 92, 151, 89, 217, 27, 248, 171, 107, 129, 236, 56 }
- attributes:
  - stun-zig.src.rfc5389.union:21:43{ .xor_mapped_address = XorMappedAddress{ .xor_addr = 94.18.164.67:36960 } }
```
