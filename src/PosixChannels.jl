"""
PosixChannels provides an `AbstractChannel`-compatible channel using POSIX message queues.

The high level API is available through [`PosixChannel`](@ref).

For more informations on POSIX message queues, see [`man 7 mq_overview`](https://man7.org/linux/man-pages/man7/mq_overview.7.html).
"""
module PosixChannels

# found in /usr/include/bits/fcntl-linux.h
const O_RDONLY::UInt32 = 0o00
const O_WRONLY::UInt32 = 0o01
const O_RDWR::UInt32 = 0o02
const O_CREAT::UInt32 = 0o0100
const O_EXCL::UInt32 = 0o0200
const O_NONBLOCK::UInt32 = 0o4000
const O_CLOEXEC::UInt32 = 0o2000000

const S_RUSR::UInt32 = 0o400 # Read by owner.
const S_WUSR::UInt32 = 0o200 # Write by owner.
const S_RGRP::UInt32 = S_RUSR >> 3 
const S_WGRP::UInt32 = S_WUSR >> 3
const S_ROTH::UInt32 = S_RGRP >> 3 
const S_WOTH::UInt32 = S_WGRP >> 3

"""
    correct_name(name)

Prepend the string `name` with a "/" if it does not start with "/".
"""
correct_name(name) = if !startswith(name, "/")
    "/" * name
else
    name
end
 
const KEYWORDS_DOC = """
# Arguments
See [`man 3 mq_open`](https://man7.org/linux/man-pages/man3/mq_open.3.html) for details.

## All usages
- `mode::Symbol=:rw`: the opening mode of the POSIX queue, can be `:r`, `:w`, or `:rw`.
- `cloexec::Bool=false`: Activate the `O_CLOEXEC` flag.
- `create::Bool=true`: Activate the `O_CREAT` flag.
- `excl::Bool=false`: Activate the `O_CREAT` flag.
- `nonblock::Bool=false`: Activate the `O_NONBLOCK` flag.

## Creation specifics
When creating a new queue (flag `O_CREAT` activated), it is necessary to provide additional informations. 

- `create_r_user::Bool=true`: Make queue readable for user.
- `create_w_user::Bool=true`: Make queue writable for user.
- `create_r_group::Bool=true`: Make queue readable for the group of the user.
- `create_w_group::Bool=true`: Make queue writable for the group of the user.
- `create_r_other::Bool=false`: Make queue readable for other users.
- `create_w_other::Bool=false`: Make queue writable for other users.
- `create_len::Int=systemmsgdefault()`: Maximum number of messages in the queue.
"""

################################################################################
#                                 C interface                                  #
################################################################################

"""
Mirror of the `mq_attr` structure used in C to configure a message queue.

See also [`open_posix_mqueue`](@ref), [`getattr_posix_mqueue`](@ref).
"""
struct mq_attr 
    "Flags (ignored for mq_open())"
    mq_flags::Int 
    "Max. # of messages on queue"
    mq_maxmsg::Int 
    "Max. message size (bytes)"
    mq_msgsize::Int
    "# of messages currently in queue (ignored for mq_open())"
    mq_curmsgs::Int
end
"""
    mq_attr()

Construct a zero-ed `mq_attr`.
"""
mq_attr() = mq_attr(0,0,0,0)

"""
    open_posix_mqueue(name, flags[, perm, attr])

Call the C function `mq_open` with the given name and flags. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror). `name` is corrected using [`correct_name`](@ref).


When `O_CREAT` flag is on, `perm` and `attr` are required.

See [`man 3 mq_open`](https://man7.org/linux/man-pages/man3/mq_open.3.html) for details.

See also [`close_posix_mqueue`](@ref).
"""
function open_posix_mqueue(name::String, flag::UInt32)
    v = @ccall mq_open(correct_name(name)::Cstring, flag::Cint)::Cint
    Base.systemerror("mq_open", v==-1)
    v
end

function open_posix_mqueue(name::String, flag::UInt32, perm::UInt32, attr::mq_attr)
    v = @ccall mq_open(correct_name(name)::Cstring, flag::Cint, perm::Cint, Ref{mq_attr}(attr)::Ptr{Cvoid})::Cint
    Base.systemerror("mq_open", v==-1)
    v
end

"""
    open_posix_mqueue(name; kwargs...)

Call `mq_open` by explicitely constructing the various flags beforehand.

$KEYWORDS_DOC
- `create_msg_size::Int=systemmsgsizedefault()`: Maximum size of a message.
"""
function open_posix_mqueue(name::String; mode=:rw, cloexec=false, create=true, excl=false, nonblock=true, create_r_user=true, create_w_user=true, create_r_group=true, create_w_group=true, create_r_other=false, create_w_other=false, create_msg_size=systemmsgsizedefault(), create_len=systemmsgdefault())
    flag = UInt32(0)
    if mode == :rw
        flag |= O_RDWR
    elseif mode == :r
        flag |= O_RDONLY
    elseif mode == :w
        flag |= O_WRONLY
    else
        error("Unknown mode $mode")
    end
    if cloexec
        flag |= O_CLOEXEC
    end
    if create
        flag |= O_CREAT
    end
    if excl
        flag |= O_EXCL
    end
    if nonblock
        flag |= O_NONBLOCK
    end
    if !create
        open_posix_mqueue(name, flag)
    else
        perm = UInt32(0)
        if create_r_user
            perm |= S_RUSR
        end
        if create_w_user
            perm |= S_WUSR
        end
        if create_r_group
            perm |= S_RGRP
        end
        if create_w_group
            perm |= S_WGRP
        end
        if create_r_other
            perm |= S_ROTH
        end
        if create_w_other
            perm |= S_WOTH
        end
        open_posix_mqueue(name, flag, perm, mq_attr(0, create_len, create_msg_size, 0))
    end
end

"""
    close_posix_mqueue(key)

Call the C function `mq_close` with the given key. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror).

See [`man 3 mq_close`](https://man7.org/linux/man-pages/man3/mq_close.3.html) for details.

See also [`open_posix_mqueue`](@ref), [`unlink_posix_mqueue`](@ref).
"""
function close_posix_mqueue(key)
    v = @ccall mq_close(key::Cint)::Cint
    Base.systemerror("mq_close", v==-1)
    v
end

"""
    unlink_posix_mqueue(name)

Call the C function `mq_close` with the given name. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror).

See [`man 3 mq_unlink`](https://man7.org/linux/man-pages/man3/mq_unlink.3.html) for details.

See also [`open_posix_mqueue`](@ref), [`close_posix_mqueue`](@ref).
"""
function unlink_posix_mqueue(name)
    v = @ccall mq_unlink(name::Cstring)::Cint
    Base.systemerror("mq_unlink", v==-1)
    v
end

"""
    send_posix_mqueue(key, val, prio=0)

    Call the C function `mq_send` with the given key, value, and priority. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror).

See [`man 3 mq_send`](https://man7.org/linux/man-pages/man3/mq_send.3.html) for details.

See also [`open_posix_mqueue`](@ref), [`close_posix_mqueue`](@ref), [`receive_posix_mqueue`](@ref).
"""
function send_posix_mqueue(key, val::T, prio=0) where T
    size = sizeof(val)
    v = @ccall mq_send(key::Cint, Ref{T}(val)::Ptr{Cvoid}, size::Csize_t, prio::Cuint)::Cint
    Base.systemerror("mq_send", v==-1)
    v
end

"""
    receive_posix_mqueue(key, type[, prio])

Call the C function `mq_receive` with the given key, and priority. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror). An element of type `type` is retreived. If the priority is given, only messages with priority `prio` are fetched. Else, the oldest message is fetched.

See [`man 3 mq_receive`](https://man7.org/linux/man-pages/man3/mq_receive.3.html) for details.

See also [`open_posix_mqueue`](@ref), [`close_posix_mqueue`](@ref), [`send_posix_mqueue`](@ref).
"""
function receive_posix_mqueue(key, ::Type{T}, prio) where T
    size = sizeof(T)
    array = Array{UInt8}(undef, size)
    v = @ccall mq_receive(key::Cint, Ref(array)::Ptr{Cvoid}, size::Csize_t, Ref(prio)::Ptr{Cuint})::Cint
    Base.systemerror("mq_receive", v==-1)
    reinterpret(T, array)
end

function receive_posix_mqueue(key, ::Type{T}) where T
    size = sizeof(T)
    array = Array{UInt8}(undef, size)
    v = @ccall mq_receive(key::Cint, pointer(array)::Ptr{Cvoid}, size::Csize_t, C_NULL::Ptr{Cuint})::Cint
    Base.systemerror("mq_receive", v==-1)
    unsafe_load(Ptr{T}(pointer(array)))
end

"""
    getattr_posix_mqueue(key)

Call the C function `mq_getattr` with the given key. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror).

See [`man 3 mq_getattr`](https://man7.org/linux/man-pages/man3/mq_getattr.3.html) for details.

See also [`mq_attr`](@ref).
"""
function getattr_posix_mqueue(key)
    size = sizeof(mq_attr)
    array = Array{UInt8}(undef, size)
    v = @ccall mq_getattr(key::Cint, pointer(array)::Ptr{Cvoid})::Cint
    Base.systemerror("mq_getattr", v==-1)
    unsafe_load(Ptr{mq_attr}(pointer(array))) 
end

################################################################################
#                             High-level interface                             #
################################################################################

"""
An impementation of `AbstractChannel` that uses POSIX message queues.
"""
struct PosixChannel{T} <: AbstractChannel{T}
    key::Int32
    name::String
    cond::Base.AsyncCondition
end
"""
    PosixChannel{T}(name, kwargs...)

Create a `PosixChannel` that works with messages of type `T`.

*Notes*: `T` must be a plain data type (`isbitstype` must return `true`), and the message queue must allow for messages of at least `sizeof(T)`.

# Extended help

$KEYWORDS_DOC
- `create_msg_size::Int=sizeof(T)`: Maximum size of a message.

# Examples

Start two julia REPL (a sender and a receiver).

`sender.jl`:
```julia
using PosixChannels

chan = PosixChannel{Int}("posix_channels_are_fun", mode=:w)
print("Press [Enter] when you are ready to send data.")
readline()

for i in 1:10
    put!(chan, i)
end

println("Done!")
println("Closing the channel.")
close(chan)

```

`receiver.jl`
```julia
using PosixChannels

chan = PosixChannel{Int}("posix_channels_are_fun", mode=:r)
println("Listening for 10 incoming Int, you may start sending")

for _ in 1:10
    while !isready(chan)
        wait(chan)
    end
    msg = take!(chan)
    println("Received \$msg")
end

println("Done!")
println("Closing the channel.")
close(chan)
println("Deleting the channel.")
unlink(chan)
```

You can then launch each script, and press return in the sender's window.

```bash
\$ julia --project sender.jl
Press [Enter] when you are ready to send data.
Done!
Closing the channel.
```

```bash
\$ julia --project receiver.jl
Listening for 10 incoming Int, you may start sending
Received 1
Received 2
Received 3
Received 4
Received 5
Received 6
Received 7
Received 8
Received 9
Received 10
Done!
Closing the channel.
Deleting the channel.
```

!!! note "Types of messages"

    This example uses integers, but any type that verifies `isbitstype` could be used. See [`StaticStrings`](https://github.com/mkitti/StaticStrings.jl) for example.

See also [`wait`](@ref), [`put!`](@ref), [`take!`](@ref), [`unlink`](@ref), [`isnonblocking`](@ref).
"""
function PosixChannel{T}(name::String; kwargs...) where T
    @assert isbitstype(T) "Channel type must be a plain data type."
    key = open_posix_mqueue(name; create_msg_size=sizeof(T), kwargs...)

    attr = getattr_posix_mqueue(key)
    @assert attr.mq_msgsize ≥ sizeof(T) "The posix message queue does not support messages this long."

    PosixChannel{T}(key, correct_name(name), Base.AsyncCondition())
end

""
Base.close(c::PosixChannel) = close_posix_mqueue(c.key)

"""
    unlink(chan)

POSIX messages queues are persistent. This allows destroying a queue.
"""
unlink(c::PosixChannel) = unlink_posix_mqueue(c.name)

"""
    isnonblocking(chan)

Checks the `O_NONBLOCK` flag of a PosixChannel.

See also [`mq_attr`](@ref).
"""
function isnonblocking(c::PosixChannel)
    attr = getattr_posix_mqueue(c.key)
    (attr.mq_flags & O_NONBLOCK) > 0
end

""
function Base.length(c::PosixChannel)
    attr = getattr_posix_mqueue(c.key)
    attr.mq_curmsgs
end

################################################################################
#                            Notification machinery                            #
################################################################################

"""
Mirror of the `sigevent` structure used in C to configure signal events.
See `/usr/include/bits/types/sigevent_t.h`.

See also [`notify_channel`](@ref), [`register_notifier_cfunction`](@ref).
"""
struct sigevent
    "Data passed with notification"
    sigev_value::Ptr{Cvoid} 
    "Notification signal"
    sigev_signo::Int32 
    "Notification method"
    sigev_notify::Int32 
    "Function used for thread notification (SIGEV_THREAD)"
    sigev_notify_function::Ptr{Cvoid} 
    "Attributes for notification thread (SIGEV_THREAD)"
    sigev_notify_attributes::Ptr{Cvoid}
end

"""
    notify_channel(handle)

Callback for the C function `mq_notify`. It only `@ccall uv_async_send` with the handle of the [`AsyncCondition`](https://docs.julialang.org/en/v1/base/base/#Base.AsyncCondition) from the channel.

See [the manual](https://docs.julialang.org/en/v1/manual/calling-c-and-fortran-code/#Thread-safety) for an explanation.

See also [`register_notifier_cfunction`](@ref).
"""
function notify_channel(handle)::Cint
    @ccall uv_async_send(handle::Ptr{Cvoid})::Cint
end

const SIGEV_THREAD::UInt32 = 2

"""
    register_notifier_cfunction(chan)


Call the C function `mq_notify` for the message queue. Checks for errors using [`Base.systemerror`](https://docs.julialang.org/en/v1/base/c/#Base.systemerror). 

`mq_notify` is called with the `SIGEV_THREAD` flag and configured to call [`notify_channel`](@ref) with the channel's condition handle as a parameter. This is done so the OS will start a thread that will unlock the condition when a new message is posted to the empty queue. This function is used by `wait` before it starts waiting for the channel's condition.

See [`man 3 mq_notify`](https://man7.org/linux/man-pages/man3/mq_notify.3.html) for details.

See also [`notify_channel`](@ref)
"""
function register_notifier_cfunction(chan::PosixChannel)
    ptr_notify_channel = @cfunction(notify_channel, Cint, (Ptr{Cvoid}, ))
    sevp = sigevent(
        chan.cond.handle,
        0,
        SIGEV_THREAD,
        ptr_notify_channel,
        C_NULL,
    )

    v = @ccall mq_notify(chan.key::Cint, Ref(sevp)::Ptr{Cvoid})::Cint
    Base.systemerror("mq_notify", v==-1)

    v
end

################################################################################
#                          AbstractChannel interface.                          #
################################################################################

"""
    put!(chan::PosixChannel, v[, prio=0])

Add a message to a PosixChannel, with priority `prio`.

See [`man 3 mq_send`](https://man7.org/linux/man-pages/man3/mq_send.3.html) for details.

See also [`send_posix_mqueue`](@ref).
"""
function Base.put!(c::PosixChannel{T}, v, prio=0) where T
    v_T = convert(T, v)
    send_posix_mqueue(c.key, v_T, prio)
end

Base.take!(c::PosixChannel{T}) where T = receive_posix_mqueue(c.key, T)
"""
    take!(chan::PosixChannel [, prio])

Take a message from a PosixChannel. If a priority is set, the oldest message with priority `prio` is taken.

See [`man 3 mq_receive`](https://man7.org/linux/man-pages/man3/mq_receive.3.html) for details.

See also [`receive_posix_mqueue`](@ref).
"""
Base.take!(c::PosixChannel{T}, prio) where T = receive_posix_mqueue(c.key, T, prio)

""
Base.isready(c::PosixChannel) = length(c) > 0

"""
You cannot `fetch` from a PosixChannel.
"""
Base.fetch(::PosixChannel) = error("Fetching is unsupported for PosixChannel.")

""
function Base.wait(chan::PosixChannel)
    if !isready(chan)
        register_notifier_cfunction(chan)
        wait(chan.cond)
    end
end

################################################################################
#                               /proc utilities                                #
################################################################################

PROC_MSG_DEFAULT = "/proc/sys/fs/mqueue/msg_default"
PROC_MSG_MAX = "/proc/sys/fs/mqueue/msg_max"
PROC_MSG_SIZE_DEFAULT = "/proc/sys/fs/mqueue/msgsize_default"
PROC_MSG_SIZE_MAX = "/proc/sys/fs/mqueue/msgsize_max"
PROC_QUEUES_MAX = "/proc/sys/fs/mqueue/queues_max"

"""
    systemmsgdefault()

Return the system's default number of messages in a message queue.

See also [`systemmsgdefault!`](@ref).
"""
systemmsgdefault() = parse(Int, read(PROC_MSG_DEFAULT, String))
"""
    systemmsgdefault!(val)

Set the system's default number of messages in a message queue.

!!! warning
    Root privileges are likely needed.

See also [`systemmsgdefault`](@ref).
"""
systemmsgdefault!(val) = write(PROC_MSG_DEFAULT, string(val))
"""
    systemmsgmax()

Return the system's max number of messages in a message queue.

See also [`systemmsgmax!`](@ref).
"""
systemmsgmax() = parse(Int, read(PROC_MSG_MAX, String))
"""
    systemmsgmax!(val)

Set the system's max number of messages in a message queue.

!!! warning
    Root privileges are likely needed.

See also [`systemmsgmax`](@ref).
"""
systemmsgmax!(val) = write(PROC_MSG_MAX, string(val))
"""
    systemmsgsizedefault()

Return the system's default size of messages in a message queue.

See also [`systemmsgdefault!`](@ref).
"""
systemmsgsizedefault() = parse(Int, read(PROC_MSG_SIZE_DEFAULT, String))
"""
    systemmsgsizedefault!(val)

Set the system's default size of messages in a message queue.

!!! warning
    Root privileges are likely needed.

See also [`systemmsgsizedefault`](@ref).
"""
systemmsgsizedefault!(val) = write(PROC_MSG_SIZE_DEFAULT, string(val))
"""
    systemmsgsizemax()

Return the system's max size of messages in a message queue.

See also [`systemmsgsizemax!`](@ref).
"""
systemmsgsizemax() = parse(Int, read(PROC_MSG_SIZE_MAX, String))
"""
    systemmsgsizemax!(val)

Set the system's max size of messages in a message queue.

!!! warning
    Root privileges are likely needed.

See also [`systemmsgsizemax`](@ref).
"""
systemmsgsizemax!(val) = write(PROC_MSG_SIZE_MAX, string(val))
"""
    systemqueuesmax()

Return the system's max number of message queue.

See also [`systemqueuesmax!`](@ref).
"""
systemqueuesmax() = parse(Int, read(PROC_QUEUES_MAX, String))
"""
    systemqueuesmax!(val)

Set the system's max number of message queue.

!!! warning
    Root privileges are likely needed.

See also [`systemqueuesmax`](@ref).
"""
systemqueuesmax!(val) = write(PROC_QUEUES_MAX, string(val))


export PosixChannel, unlink, isnonblocking

end
