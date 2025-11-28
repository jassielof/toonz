pub const CommandError = error{
    UnknownCommand,
    InvalidArguments,
    FileNotFound,
    ZonNotSupported,
    Unimplemented,
};
