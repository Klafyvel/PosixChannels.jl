# PosixChannels

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://klafyvel.github.io/PosixChannels.jl/dev/) [![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://klafyvel.github.io/PosixChannels.jl/stable/) [![Build Status](https://github.com/klafyvel/PosixChannels.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/klafyvel/PosixChannels.jl/actions/workflows/CI.yml?query=branch%3Amain) 

PosixChannels provides an `AbstractChannel`-compatible channel using POSIX message queues.

The high level API is available through [`PosixChannel`](https://klafyvel.github.io/PosixChannels.jl/dev/#PosixChannels.PosixChannel).

For more information on POSIX message queues, see [`man 7 mq_overview`](https://man7.org/linux/man-pages/man7/mq_overview.7.html).

