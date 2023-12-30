module PosixChannels
#
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

correct_name(name) = if !startswith(name, "/")
        "/" * name
    else
        name
    end
 
struct mq_attr 
    mq_flags::Int # Flags (ignored for mq_open())
    mq_maxmsg::Int # Max. # of messages on queue
    mq_msgsize::Int # Max. message size (bytes)
    mq_curmsgs::Int # # of messages currently in queue (ignored for mq_open())
end
mq_attr() = mq_attr(0,0,0,0)

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

function open_posix_mqueue(name::String; mode=:rw, cloexec=false, create=true, excl=false, nonblock=true, create_r_user=true, create_w_user=true, create_r_group=true, create_w_group=true, create_r_other=false, create_w_other=false, create_msg_size=1, create_len=10)
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

function close_posix_mqueue(key)
    v = @ccall mq_close(key::Cint)::Cint
    Base.systemerror("mq_close", v==-1)
    v
end

function unlink_posix_mqueue(name)
    v = @ccall mq_unlink(name::Cstring)::Cint
    Base.systemerror("mq_unlink", v==-1)
    v
end

function send_posix_mqueue(key, val::T, prio=0) where T
    size = sizeof(val)
    v = @ccall mq_send(key::Cint, Ref{T}(val)::Ptr{Cvoid}, size::Csize_t, prio::Cuint)::Cint
    Base.systemerror("mq_send", v==-1)
    v
end

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

function getattr_posix_mqueue(key)
    size = sizeof(mq_attr)
    array = Array{UInt8}(undef, size)
    v = @ccall mq_getattr(key::Cint, pointer(array)::Ptr{Cvoid})::Cint
    Base.systemerror("mq_getattr", v==-1)
    unsafe_load(Ptr{mq_attr}(pointer(array))) 
end

struct PosixChannel{T} <: AbstractChannel{T}
    key::Int32
    name::String
    cond::Base.AsyncCondition
end
function PosixChannel{T}(name::String; kwargs...) where T
    @assert isbitstype(T) "Channel type must be a plain data type."
    key = open_posix_mqueue(name; create_msg_size=sizeof(T), kwargs...)

    attr = getattr_posix_mqueue(key)
    @assert attr.mq_msgsize ≥ sizeof(T) "The posix message queue does not support messages this long."

    l = ReentrantLock()
    PosixChannel{T}(key, correct_name(name), Base.AsyncCondition())
end

Base.close(c::PosixChannel) = close_posix_mqueue(c.key)

unlink(c::PosixChannel) = unlink_posix_mqueue(c.name)

function isnonblocking(c::PosixChannel)
    attr = getattr_posix_mqueue(c.key)
    (attr.mq_flags & O_NONBLOCK) > 0
end

function Base.put!(c::PosixChannel{T}, v, prio=0) where T
    v_T = convert(T, v)
    send_posix_mqueue(c.key, v_T, prio)
end

Base.take!(c::PosixChannel{T}) where T = receive_posix_mqueue(c.key, T)
Base.take!(c::PosixChannel{T}, prio) where T = receive_posix_mqueue(c.key, T, prio)

function Base.length(c::PosixChannel)
    attr = getattr_posix_mqueue(c.key)
    attr.mq_curmsgs
end

Base.isready(c::PosixChannel) = length(c) > 0

struct sigevent
    sigev_value::Ptr{Cvoid} # Data passed with notification
    sigev_signo::Int32 # Notification signal
    sigev_notify::Int32 # Notification method
    sigev_notify_function::Ptr{Cvoid} # Function used for thread notification (SIGEV_THREAD)
    sigev_notify_attributes::Ptr{Cvoid} # Attributes for notification thread (SIGEV_THREAD)
end

function notify_channel(handle)::Cint
    @ccall uv_async_send(handle::Ptr{Cvoid})::Cint
end
ptr_notify_channel = @cfunction(notify_channel, Cint, (Ptr{Cvoid}, ))

const SIGEV_THREAD::UInt32 = 2

function register_notifier_cfunction(chan::PosixChannel)
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

function Base.wait(chan::PosixChannel)
    register_notifier_cfunction(chan)
    wait(chan.cond)
end


export PosixChannel, unlink, isnonblocking

end
