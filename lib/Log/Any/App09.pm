package Log::Any::App09;
# VERSION
require Log::Any::App;
die "We don't have the correct version of Log::Any::App ".
    "($Log::Any::App09::VERSION vs $Log::Any::App::VERSION), ".
    "please reinstall Log-Any-App09\n"
    unless $Log::Any::App::VERSION eq $Log::Any::App09::VERSION;

1;
# ABSTRACT: An easy way to use Log::Any in applications
