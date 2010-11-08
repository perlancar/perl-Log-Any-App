package Log::Any::App;
# ABSTRACT: An easy way to use Log::Any in applications

=head1 SYNOPSIS

    # in your script/application
    use Log::Any::App qw($log);

    # or, in command line
    % perl -MLog::Any::App -MModuleThatUsesLogAny -e ...

=head1 DESCRIPTION

L<Log::Any> makes life easy for module authors. All you need to do is:

 use Log::Any qw($log);

and you're off producing logs with $log->debug(), $log->info(), $log->error(),
etc. That's it. The task of consuming logs (setting up each output, deciding
which messages gets to which output, etc) rests on the shoulder of module users.

Life is not equally easy for the module users (or application authors) though.
The typical incantation to consume logs (assuming we use the Log::Log4perl
adapter) is:

 use Log::Any qw($log);
 use Log::Any::Adapter;
 use Log::Log4perl;
 my $log4perl_config = '
   some
   long
   multiline
   config...';
 Log::Log4perl->init(\$log4perl_config);
 Log::Any::Adapter->set('Log4perl');

Frankly, I couldn't possibly remember all that (especially the details of
Log4perl configuration), hence Log::Any::App. The goal of Log::Any::App is to
make life equally easy for log consumers. All you need to do is:

 use Log::Any::App qw($log);

or, from the command line:

 perl -MLog::Any::App='$log' -MModuleThatUsesLogAny -e ...

and you can display the logs in screen, file(s), syslog, etc. You can also log
using $log->debug(), etc as usual. Most of the time you don't need to configure
anything as Log::Any::App will construct the most appropriate default Log4perl
config for your application.

I mostly use Log::Any;:App in oneliners and simple to medium scripts whenever I
have to use Log::Any-using modules (for example: L<Data::Schema> and
L<Config::Tree>).

=cut

use 5.010;
use strict;
use warnings;

use Data::Dumper;
use File::HomeDir;
use File::Path qw(make_path);
use File::Spec;
use Log::Any 0.11;
use Log::Any::Adapter;
use Log::Log4perl;
# use Log::Dispatch::Dir
# use Log::Dispatch::FileRotate
# use Log::Dispatch::Syslog

use vars qw($dbg_ctx);

my %PATTERN_STYLES = (
    plain             => '%m',
    script_short      => '[%r] %m%n',
    script_long       => '[%d] %m%n',
    daemon            => '[pid %P] [%d] %m%n',
    syslog            => '[pid %p] %m',
);

=head1 USING AND EXAMPLES

Using Log::Any::App is very easy. Most of the time you just need to do this from
command line:

 % perl -MLog::Any::App -MModuleThatUsesLogAny -e ...

or from a script:

 use ModuleThatUsesLogAny;
 use Log::Any::App '$log';

This will send logs to screen as well as file (~/$SCRIPT_NAME.log or
/var/log/$SCRIPT_NAME.log if running as root, command-line scripts by default do
not log to file) with the default level of 'warn'. This means $log->error("foo")
will display, while $log->info("bar") will not.

The 'use Log::Any::App' statement can be issued before or after the modules that
use Log::Any, it doesn't matter. Logging will be initialized in the INIT phase.

=head2 Changing logging level

Changing logging level can be done from the script or outside the script. From
the script:

 use Log::Any::App '$log', -level => 'debug';

but oftentimes what you want is changing level without modifying the script
itself. So leave it to Log::Any::App to determine level:

 use Log::Any::App '$log';

and then you can use environment variable:

 TRACE=1 script.pl;       # setting level to trace
 DEBUG=1 script.pl;       # setting level to debug
 VERBOSE=1 script.pl;     # setting level to info
 QUIET=1 script.pl;       # setting level to error
 LOG_LEVEL=... script.pl; # setting a specific log level

or command-line options:

 script.pl --trace
 script.pl --debug
 script.pl --verbose
 script.pl --quiet
 script.pl --log_level=debug;   # '--log-level debug' will also do

Log::Any::App won't interfere with command-line processing modules like
L<Getopt::Long> or L<App::Options>.

=head2 Changing default level

The default log level is 'warn'. You can change this using:

 use Log::Any::App '$log';
 BEGIN { our $Log_Level = 'info' }

and then you can still use environment or command-line options to override the
setting.

=head2 Changing per-output level

Logging level can also be specified on a per-output level. For example, if you
want your script to be chatty on the screen but still logs to file at the default
'warn' level:

 SCREEN_VERBOSE=1 script.pl
 SCREEN_DEBUG=1 script.pl
 SCREEN_TRACE=1 script.pl
 SCREEN_LOG_LEVEL=info script.pl

 script.pl --screen_verbose
 script.pl --screen-debug
 script.pl --screen-trace=1
 script.pl --screen-log-level=info
 # and so on

Similarly, to set only file level, use FILE_VERBOSE, FILE_LOG_LEVEL,
--file-trace, etc.

=head2 Setting default per-output level

As with setting default level, you can also set default level on a per-output
basis:

 use Log::Any::App '$log';
 BEGIN {
     our $Screen_Log_Level = 'off';
     our $File_Quiet = 1; # setting level to 'error'
     # and so on
 }

If a per-output level is not specifed, it will default to the general log level.

=head2 Enabling/disabling output

To disable a certain output, you can do this:

 use Log::Any::App '$log', -file => 0;

or:

 use Log::Any::App '$log', -screen => {level=>'off'};

and this won't allow it to be reenabled from outside the script. However if you
do this:

 use Log::Any::App;
 BEGIN { our $Screen_Log_Level = 'off' }

then you will be able to override the screen log level using environment or
command-line options (SCREEN_DEBUG, --screen-verbose, and so on).

=head2 Changing log file name/location

By default Log::Any::App will use ~/$NAME.log (or /var/log/$NAME.log if script is
running as root), where $NAME taken from $0, but can be changed using:

 use Log::Any::App '$log', -name => 'myprog';

Or, using custom path:

 use Log::Any::App '$log', -file => '/path/to/file';

=head2 Changing other output parameters

Each output argument can accept a hashref to specify various options. For
example:

 use Log::Any::App '$log',
     -screen => {color=>0},   # never use color
     -file   => {path=>'/var/log/foo',
                 rotate=>'10M',
                 histories=>10,
                },

For all the available options of each output, see the init() function.

=head2 Logging to syslog

Logging to syslog is enabled by default if your script looks like a daemon, e.g.:

 use Net::Daemon; # this indicate your program is a daemon
 use Log::Any::App; # syslog logging will be turned on by default

but if you don't want syslog logging:

 use Log::Any::App -syslog => 0;

=head2 Logging to directory

This is done using L<Log::Dispatch::Dir> where each log message is logged to a
different file in a specified directory. By default logging to dir is not turned
on, to turn it on:

 use Log::Any::App '$log', -dir => 1;

For all the available options of directory output, see the init() function.

=head2 Multiple outputs

Each output argument can accept an arrayref to specify more than one output,
example:

 use Log::Any::App '$log',
     -file => ["/var/log/log1",
               {path=>"/var/log/debug_foo", category=>'Foo', level=>'debug'}];

=head2 Changing level of a certain module

Suppose you want to shut up Foo, Bar::Baz, and Qux's logging because they are too
noisy:

 use Log::Any::App '$log',
     -category_level => { Foo => 'off', 'Bar::Baz' => 'off', Qux => 'off' };

or (same thing):

 use Log::Any::App '$log',
     -category_alias => { -noisy => [qw/Foo Bar::Baz Qux/] },
     -category_level => { -noisy => 'off' };

You can even specify this on a per-output basis. Suppose you only want to shut
the noisy modules on the screen, but not on the file:

 use Log::Any::App '$log',
    -category_alias => { -noisy => [qw/Foo Bar::Baz Qux/] },
    -screen => { category_level => { -noisy => 'off' } };

or perhaps, you want to shut the noisy modules everywhere, except on the screen:

 use Log::Any::App '$log',
     -category_alias => { -noisy => [qw/Foo Bar::Baz Qux/] },
     -category_level => { -noisy => 'off' },
     -syslog => 1,
     -file   => "/var/log/foo",
     -screen => { category_level => {} }; # do not do per-category level

=head2 Preventing logging level to be changed from outside the script

Sometimes, for security/audit reasons, you don't want to allow script caller to
change logging level. To do so, just specify the 'level' option in the script
during 'use' statement:

=head2 Debugging

To see the Log4perl configuration that is generated by Log::Any::App and how it
came to be, set environment LOGANYAPP_DEBUG to true.


=head1 FUNCTIONS

=head2 init(\@args)

This is the actual function that implements the setup and
configuration of logging. You normally need not call this function
explicitly, it will be called once in an INIT block. In fact, when you
do:

 use Log::Any::App 'a', 'b', 'c';

it is actually passed as:

 init(['a', 'b', 'c']);

Arguments to init can be one or more of:

=over 4

=item -init => BOOL

Whether to call Log::Log4perl->init() after setting up the Log4perl
configuration. Default is true. You can set this to false, and you can initialize
Log4perl yourself (but then there's not much point in using this module, right?)

=item -name => STRING

Change the program name. Default is taken from $0.

=item -category_alias => {ALIAS=>CATEGORY, ...}

Create category aliases so the ALIAS can be used in place of real categories in
each output's category specification. For example, instead of doing this:

 init(
     -file   => [category=>[qw/Foo Bar Baz/], ...],
     -screen => [category=>[qw/Foo Bar Baz/]],
 );

you can do this instead:

 init(
     -category_alias => {_fbb => [qw/Foo Bar Baz/]},
     -file   => [category=>'-fbb', ...],
     -screen => [category=>'-fbb', ...],
 );

=item -category_level => {CATEGORY=>LEVEL, ...}

Specify per-category level. Categories not mentioned on this will use the general
level (-level). This can be used to increase or decrease logging on certain
categories/modules.

=item -level => 'trace'|'debug'|'info'|'warn'|'error'|'fatal'|'off'

Specify log level for all outputs. Each output can override this value. The
default log level is determined as follow:

If L<App::Options> is present, these keys are checked in
B<%App::options>: B<log_level>, B<trace> (if true then level is
C<trace>), B<debug> (if true then level is C<debug>), B<verbose> (if
true then level is C<info>), B<quiet> (if true then level is
C<error>).

Otherwise, it will try to scrape @ARGV for the presence of
B<--log-level>, B<--trace>, B<--debug>, B<--verbose>, or B<--quiet>
(this usually works because Log::Any::App does this in the INIT phase,
before you call L<Getopt::Long>'s GetOptions() or the like).

Otherwise, it will look for environment variables: B<LOG_LEVEL>,
B<QUIET>. B<VERBOSE>, B<DEBUG>, B<TRACE>.

Otherwise, it will try to search for package variables in the C<main>
namespace with names like C<$Log_Level> or C<$LOG_LEVEL> or
C<$log_level>, C<$Quiet> or C<$QUIET> or C<$quiet>, C<$Verbose> or
C<$VERBOSE> or C<$verbose>, C<$Trace> or C<$TRACE> or C<$trace>,
C<$Debug> or C<$DEBUG> or C<$debug>.

If everything fails, it defaults to 'warn'.

=item -file => 0 | 1|yes|true | PATH | {opts} | [{opts}, ...]

Specify output to one or more files, using
L<Log::Dispatch::FileRotate>.

If the argument is a false boolean value, file logging will be turned off. If
argument is a true value that matches /^(1|yes|true)$/i, file logging will be
turned on with default path, etc. If the argument is another scalar value then it
is assumed to be a path. If the argument is a hashref, then the keys of the
hashref must be one of: C<level>, C<path>, C<max_size> (maximum size before
rotating, in bytes, 0 means unlimited or never rotate), C<histories> (number of
old files to keep, excluding the current file), C<category> (a string of ref to
array of strings), C<category_level> (a hashref, similar to -category_level),
C<pattern_style> (see L<"PATTERN STYLES">), C<pattern> (Log4perl pattern).

If the argument is an arrayref, it is assumed to be specifying
multiple files, with each element of the array as a hashref.

How Log::Any::App determines defaults for file logging:

If program is a one-liner script specified using "perl -e", the
default is no file logging. Otherwise file logging is turned on.

If the program runs as root, the default path is
C</var/log/$NAME.log>, where $NAME is taken from B<$0> (or
C<-name>). Otherwise the default path is ~/$NAME.log. Intermediate
directories will be made with L<File::Path>.

Default rotating behaviour is no rotate (max_size = 0).

Default level for file is the same as the global level set by
B<-level>. But App::options, command line, environment, and package
variables in main are also searched first (for B<FILE_LOG_LEVEL>,
B<FILE_TRACE>, B<FILE_DEBUG>, B<FILE_VERBOSE>, B<FILE_QUIET>, and the
similars).

=item -dir => 0 | 1|yes|true | PATH | {opts} | [{opts}, ...]

Log messages using L<Log::Dispatch::Dir>. Each message is logged into
separate files in the directory. Useful for dumping content
(e.g. HTML, network dumps, or temporary results).

If the argument is a false boolean value, dir logging will be turned off. If
argument is a true value that matches /^(1|yes|true)$/i, dir logging will be
turned on with defaults path, etc. If the argument is another scalar value then
it is assumed to be a directory path. If the argument is a hashref, then the keys
of the hashref must be one of: C<level>, C<path>, C<max_size> (maximum total size
of files before deleting older files, in bytes, 0 means unlimited), C<max_age>
(maximum age of files to keep, in seconds, undef means unlimited). C<histories>
(number of old files to keep, excluding the current file), C<category>,
C<category_level> (a hashref, similar to -category_level), C<pattern_style> (see
L<"PATTERN STYLES">), C<pattern> (Log4perl pattern), C<filename_pattern> (pattern
of file name).

If the argument is an arrayref, it is assumed to be specifying
multiple directories, with each element of the array as a hashref.

How Log::Any::App determines defaults for dir logging:

Directory logging is by default turned off. You have to explicitly
turn it on.

If the program runs as root, the default path is C</var/log/$NAME/>,
where $NAME is taken from B<$0>. Otherwise the default path is
~/log/$NAME/. Intermediate directories will be created with
File::Path. Program name can be changed using C<-name>.

Default rotating parameters are: histories=1000, max_size=0,
max_age=undef.

Default level for dir logging is the same as the global level set by
B<-level>. But App::options, command line, environment, and package
variables in main are also searched first (for B<DIR_LOG_LEVEL>,
B<DIR_TRACE>, B<DIR_DEBUG>, B<DIR_VERBOSE>, B<DIR_QUIET>, and the
similars).

=item -screen => 0 | 1|yes|true | {opts}

Log messages using L<Log::Log4perl::Appender::ScreenColoredLevels>.

If the argument is a false boolean value, screen logging will be turned off. If
argument is a true value that matches /^(1|yes|true)$/i, screen logging will be
turned on with default settings. If the argument is a hashref, then the keys of
the hashref must be one of: C<color> (default is true, set to 0 to turn off
color), C<stderr> (default is true, set to 0 to log to stdout instead), C<level>,
C<category>, C<category_level> (a hashref, similar to -category_level),
C<pattern_style> (see L<"PATTERN STYLE">), C<pattern> (Log4perl string pattern).

How Log::Any::App determines defaults for screen logging:

Screen logging is turned on by default.

Default level for screen logging is the same as the global level set
by B<-level>. But App::options, command line, environment, and package
variables in main are also searched first (for B<SCREEN_LOG_LEVEL>,
B<SCREEN_TRACE>, B<SCREEN_DEBUG>, B<SCREEN_VERBOSE>, B<SCREEN_QUIET>,
and the similars).

Color can also be turned on/off using environment variable COLOR (if B<color>
argument is not set).

=item -syslog => 0 | 1|yes|true | {opts}

Log messages using L<Log::Dispatch::Syslog>.

If the argument is a false boolean value, syslog logging will be turned off. If
argument is a true value that matches /^(1|yes|true)$/i, syslog logging will be
turned on with default level, ident, etc. If the argument is a hashref, then the
keys of the hashref must be one of: C<level>, C<ident>, C<facility>, C<category>,
C<category_level> (a hashref, similar to -category_level), C<pattern_style> (see
L<"PATTERN STYLES">), C<pattern> (Log4perl pattern).

How Log::Any::App determines defaults for syslog logging:

If a program is a daemon (determined by detecting modules like
L<Net::Server> or L<Proc::PID::File>) then syslog logging is turned on
by default and facility is set to C<daemon>, otherwise the default is
off.

Ident is program's name by default ($0, or C<-name>).

Default level for syslog logging is the same as the global level set
by B<-level>. But App::options, command line, environment, and package
variables in main are also searched first (for B<SYSLOG_LOG_LEVEL>,
B<SYSLOG_TRACE>, B<SYSLOG_DEBUG>, B<SYSLOG_VERBOSE>, B<SYSLOG_QUIET>,
and the similars).

=item -dump => BOOL

If set to true then Log::Any::App will dump the generated Log4perl
config. Useful for debugging the logging.

=back

=head1 PATTERN STYLES

Log::Any::App provides some styles for Log4perl patterns. You can
specify C<pattern_style> instead of directly specifying
C<pattern>. example:

 use Log::Any::App -screen => {pattern_style=>"script_long"};

 Name           Description                        Example output
 ----           -----------                        --------------
 plain          The message, the whole message,    Message
                and nothing but the message.
                Used by dir logging.

                Equivalent to pattern: '%m'

 script_short   For scripts that run for a short   [234] Message
                time (a few seconds). Shows just
                the number of milliseconds. This
                is the default for screen.

                Equivalent to pattern:
                '[%r] %m%n'

 script_long    Scripts that will run for a        [2010-04-22 18:01:02] Message
                while (more than a few seconds).
                Shows date/time.

                Equivalent to pattern:
                '[%d] %m%n'

 daemon         For typical daemons. Shows PID     [pid 1234] [2010-04-22 18:01:02] Message
                and date/time. This is the
                default for file logging.

                Equivalent to pattern:
                '[pid %P] [%d] %m%n'

 syslog         Style suitable for syslog          [pid 1234] Message
                logging.

                Equivalent to pattern:
                '[pid %p] %m'

If you have a favorite pattern style, please do share them.

=cut

my $init_args;
my $init_called;

sub init {
    return if $init_called++;

    my ($args, $caller) = @_;
    $caller ||= caller();

    my $spec = _parse_opts($args, $caller);
    return unless $spec->{init};
    _init_log4perl($spec);
}

sub _add_appender_OUTPUT {
    my (%args) = @_;
    my $config = $args{config};
    my $ospec = $args{ospec};
    my $class = $args{class};
    my $params = $args{params};

    #next if $ospec->{level} eq 'off';

    my $a = $ospec->{name};
    $config->{appenders}{$a} = {ospec => $ospec, config => join(
            "",
            "log4perl.appender.$a = $class\n",
            (map { "log4perl.appender.$a.$_ = $params->{$_}\n" } keys %$params),
            "log4perl.appender.$a.layout = PatternLayout\n",
            "log4perl.appender.$a.layout.ConversionPattern = $ospec->{pattern}\n",
        )};

    my $cats = $config->{categories};
    for my $cat (_extract_category($_)) {
        $cats->{$cat} ||= {appenders => [], level => $ospec->{level}};
        $cats->{$cat}{level} = _min_level($cats->{$cat}{level}, $ospec->{level});
        push @{ $cats->{$cat}{appenders} }, $a;
    }
    if ($ospec->{category_level}) {
        while (my ($k, $v) = each %{ $ospec->{category_level} }) {
            for my $cat (_extract_category($ospec, $k)) {
                $cats->{$cat} ||= {appenders => [], level => $ospec->{level}};
                $cats->{$cat}{level} = _min_level($cats->{$cat}{level}, $v);
                push @{ $cats->{$cat}{appenders} }, $a;
            }
        }
    }
}

sub _add_appender_dir {
    my ($config, $ospec) = @_;
    my $params = {};

    $params->{dirname}   = $ospec->{path};
    $params->{filename_pattern} = $ospec->{filename_pattern};
    $params->{max_size}  = $ospec->{max_size} if $ospec->{max_size};
    $params->{max_files} = $ospec->{histories}+1 if $ospec->{histories};
    $params->{max_age}   = $ospec->{max_age} if $ospec->{max_age};
    _add_appender_OUTPUT(
        ospec  => $ospec,
        config => $config,
        class  => "Log::Dispatch::Dir",
        params => $params,
    );
}

sub _add_appender_file {
    my ($config, $ospec) = @_;
    my $params = {};

    $params->{mode}  = 'append';
    $params->{filename} = $ospec->{path};
    $params->{size}  = $ospec->{size} if $ospec->{size};
    $params->{max}   = $ospec->{histories}+1 if $ospec->{histories};
    _add_appender_OUTPUT(
        ospec  => $ospec,
        config => $config,
        class  => "Log::Dispatch::FileRotate",
        params => $params,
    );
}

sub _add_appender_screen {
    my ($config, $ospec) = @_;
    my $params = {};

    $params->{stderr}  = $ospec->{stderr} ? 1:0;
    _add_appender_OUTPUT(
        ospec  => $ospec,
        config => $config,
        class  => "Log::Log4perl::Appender::" .
            ($ospec->{color} ? "ScreenColoredLevels" : "Screen"),
        params => $params,
    );
}

sub _add_appender_syslog {
    my ($config, $ospec) = @_;
    my $params = {};

    $params->{mode}     = 'append';
    $params->{ident}    = $ospec->{ident};
    $params->{facility} = $ospec->{facility};
    _add_appender_OUTPUT(
        ospec  => $ospec,
        config => $config,
        class  => "Log::Dispatch::Syslog",
        params => $params,
    );
}

sub _add_filters {
    my ($config) = @_;

    my $cats      = $config->{categories};
    my $appenders = $config->{appenders};
    my $filters   = $config->{filters};

    for my $a (keys %$appenders) {
        my $c = $appenders->{$a};
        my $cat = $c->{category};
        my $different;
        for (_extract_category($c->{spec})) {
            do { $different++; last } if $_ ne $cats->{$_}{level};
        }
        next unless $different;
        $c->{config} .= join(
            "",
            "log4perl.appender.$a.Filter = $a\n",
        );
        if ($c->{spec}{level} eq 'off') {
            $filters->{$a} = {config => join(
                "",
                "# turn off every level\n",
                "log4perl.filter.$a = Log::Log4perl::Filter::LevelRange\n",
                "log4perl.filter.$a.LevelMin = DEBUG\n",
                "log4perl.filter.$a.LevelMax = FATAL\n",
                "log4perl.filter.$a.AcceptOnMatch = false\n",
            )};
        } else {
            $filters->{$a} = {config => join(
                "",
                "log4perl.filter.$a = Log::Log4perl::Filter::LevelRange\n",
                "log4perl.filter.$a.LevelMin = ", uc($c->{ospec}{level}), "\n",
                "log4perl.filter.$a.LevelMax = FATAL\n",
                "log4perl.filter.$a.AcceptOnMatch = true\n",
            )};
        }
    }
}

sub _gen_l4p_config {
    my ($config) = @_;

    my $cats      = $config->{categories};
    my $appenders = $config->{appenders};
    my $filters   = $config->{filters};

    my $cats_str = '';
    for (sort {$a cmp $b} keys %$cats) {
        my $c = $cats->{$_};
        my $l = $_ eq '' ? "rootLogger" : "logger.$_";
        $cats_str .= "log4perl.$l = ".
            join(", ", uc($c->{level}), @{ $c->{appenders} })."\n";
    }

    join(
        "",
        "# categories\n",
        $cats_str, "\n",
        (keys %$filters ? "# filters\n" : ""),
        join("", map { "$filters->{$_}{config}\n" }
                 sort keys %$filters),
        (keys %$appenders ? "# appenders\n" : ""),
        join("", map { "$appenders->{$_}{config}\n" }
                 sort keys %$appenders),
    );
}

sub _init_log4perl {
    my ($spec) = @_;

    # create intermediate directories for dir
    for (@{ $spec->{dir} }) {
        my $dir = _dirname($_->{path});
        make_path($dir) if length($dir) && !(-d $dir);
    }

    # create intermediate directories for file
    for (@{ $spec->{file} }) {
        my $dir = _dirname($_->{path});
        make_path($dir) if length($dir) && !(-d $dir);
    }

    my $l4p_config = {
        filters => {},
        appenders => {},
        categories => {
            '' => {appenders => [], level => $spec->{level}},
        },
    };

    for (@{ $spec->{dir} }) {
        _add_appender_dir($l4p_config, $_);
    }
    for (@{ $spec->{file} }) {
        _add_appender_file($l4p_config, $_);
    }
    for (@{ $spec->{screen} }) {
        _add_appender_screen($l4p_config, $_);
    }
    for (@{ $spec->{syslog} }) {
        _add_appender_syslog($l4p_config, $_);
    }

    # add filters to appender with level lower than the category level
    _add_filters($l4p_config);

    my $config_str = _gen_l4p_config($l4p_config);
    if ($spec->{dump}) {
        print "Log::Any::App configuration:\n",
            Data::Dumper->new([$spec])->Terse(1)->Dump;
        print "Log4perl configuration: <<EOC\n", $config_str, "EOC\n";
    }

    Log::Log4perl->init(\$config_str);
    Log::Any::Adapter->set('Log4perl');
}

sub _basename {
    my $path = shift;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    $file;
}

sub _dirname {
    my $path = shift;
    my ($vol, $dir, $file) = File::Spec->splitpath($path);
    $dir;
}

# we separate args and opts, because we need to export logger early
# (BEGIN), but configure logger in INIT (to be able to detect
# existence of other modules).

sub _parse_args {
    my ($args, $caller) = @_;
    my $i = 0;
    while ($i < @$args) {
        my $arg = $args->[$i];
        do { $i+=2; next } if $arg =~ /^-(\w+)$/;
        if ($arg eq '$log') {
            _export_logger($caller);
        } else {
            die "Unknown arg '$arg', valid arg is '\$log' or -OPTS";
        }
        $i++;
    }
}

sub _parse_opts {
    my ($args, $caller) = @_;

    my $spec = {
        name => _basename($0),
        init => 1,
        dump => ($ENV{LOGANYAPP_DEBUG} ? 1:0),
        category_aliases => {},
    };

    my $i = 0;
    my %opts;
    while ($i < @$args) {
        my $arg = $args->[$i];
        do { $i++; next } unless $arg =~ /^-(\w+)$/;
        my $opt = $1;
        die "Missing argument for option $opt" unless $i++ < @$args-1;
        $arg = $args->[$i];
        $opts{$opt} = $arg;
        $i++;
    }

    $spec->{level} = _set_level("", "");
    if (!$spec->{level} && defined($opts{level})) {
        $spec->{level} = _check_level($opts{level}, "-level");
        _debug("Set general level to $spec->{level} (from -level)");
    } elsif (!$spec->{level}) {
        $spec->{level} = "warn";
        _debug("Set general level to $spec->{level} (default)");
    }
    delete $opts{level};

    if (defined $opts{category_alias}) {
        die "category_alias must be a hashref"
            unless ref($opts{category_alias}) eq 'HASH';
        $spec->{category_alias} = $opts{category_alias};
        delete $opts{category_alias};
    }

    if (defined $opts{category_level}) {
        die "category_alias must be a hashref"
            unless ref($opts{category_alias}) eq 'HASH';
        $spec->{category_level} = {};
        for (keys %{ $opts{category_level} }) {
            $spec->{category_level}{$_} =
                _check_level($opts{category_level}{$_}, "-category_level{$_}");
        }
        delete $opts{category_level};
    }

    if (defined $opts{init}) {
        $spec->{init} = $opts{init};
        delete $opts{init};
    }

    if (defined $opts{name}) {
        $spec->{name} = $opts{name};
        delete $opts{name};
    }

    if (defined $opts{dump}) {
        $spec->{dump} = 1;
        delete $opts{dump};
    }

    $spec->{file} = [];
    _parse_opt_file($spec, $opts{file} // ($0 ne '-e' ? 1:0));
    delete $opts{file};

    $spec->{dir} = [];
    _parse_opt_dir($spec, $opts{dir} // 0);
    delete $opts{dir};

    $spec->{screen} = [];
    _parse_opt_screen($spec, $opts{screen} // 1);
    delete $opts{screen};

    $spec->{syslog} = [];
    _parse_opt_syslog($spec, $opts{syslog} // (_is_daemon()));
    delete $opts{syslog};

    if (keys %opts) {
        die "Unknown option(s) ".join(", ", keys %opts)." Known opts are: ".
            "name, level, category_level, category_alias, dump, init, ".
                "file, dir, screen, syslog";
    }

    #use Data::Dumper; print Dumper $spec;
    $spec;
}

sub _is_daemon {
    $INC{"App/Daemon.pm"} ||
    $INC{"Daemon/Easy.pm"} ||
    $INC{"Daemon/Daemonize.pm"} ||
    $INC{"Daemon/Generic.pm"} ||
    $INC{"Daemonise.pm"} ||
    $INC{"Daemon/Simple.pm"} ||
    $INC{"HTTP/Daemon.pm"} ||
    $INC{"IO/Socket/INET/Daemon.pm"} ||
    $INC{"Mojo/Server/Daemon.pm"} ||
    $INC{"MooseX/Daemonize.pm"} ||
    $INC{"Net/Daemon.pm"} ||
    $INC{"Net/Server.pm"} ||
    $INC{"Proc/Daemon.pm"} ||
    $INC{"Proc/PID/File.pm"} ||
    $INC{"Win32/Daemon/Simple.pm"} ||
    0;
}

sub _parse_opt_OUTPUT {
    my (%args) = @_;
    my $kind = $args{kind};
    my $default_sub = $args{default_sub};
    my $spec = $args{spec};
    my $arg = $args{arg};

    return unless $arg;

    if (!ref($arg) || ref($arg) eq 'HASH') {
        my $name = uc($kind).(@{ $spec->{$kind} }+0);
        local $dbg_ctx = $name;
        push @{ $spec->{$kind} }, $default_sub->($spec);
        $spec->{$kind}[-1]{name} = $name;
        if (!ref($arg)) {
            # leave every output parameter as is
        } else {
            for my $k (keys %$arg) {
                for ($spec->{$kind}[-1]) {
                    exists($_->{$k}) or die "Invalid $kind argument: $k, please".
                        " only specify one of: " . join(", ", sort keys %$_);
                    $_->{$k} = $k eq 'level' ?
                        _check_level($arg->{$k}, "-$kind") : $arg->{$k};
                    _debug("Set level of $kind to $_->{$k} (spec)")
                        if $k eq 'level';
                }
            }
        }
        $spec->{$kind}[-1]{main_spec} = $spec;
        _set_pattern($spec->{$kind}[-1], $kind);
    } elsif (ref($arg) eq 'ARRAY') {
        for (@$arg) {
            _parse_opt_OUTPUT(%args, arg => $_);
        }
    } else {
        die "Invalid argument for -$kind, ".
            "must be a boolean or hashref or arrayref";
    }
}

sub _default_file {
    my ($spec) = @_;
    my $level = _set_level("file", "file");
    if (!$level) {
        $level = $spec->{level};
        _debug("Set level of file to $level (general level)");
    }
    return {
        level => $level,
        category_level => $spec->{category_level},
        path => $> ? File::Spec->catfile(File::HomeDir->my_home, "$spec->{name}.log") :
            "/var/log/$spec->{name}.log", # XXX and on Windows?
        max_size => undef,
        histories => undef,
        category => '',
        pattern_style => 'daemon',
        pattern => undef,
    };
}

sub _parse_opt_file {
    my ($spec, $arg) = @_;

    if (!ref($arg) && $arg && $arg !~ /^(1|yes|true)$/i) {
        $arg = {path => $arg};
    }

    _parse_opt_OUTPUT(
        kind => 'file', default_sub => \&_default_file,
        spec => $spec, arg => $arg,
    );
}

sub _default_dir {
    my ($spec) = @_;
    my $level = _set_level("dir", "dir");
    if (!$level) {
        $level = $spec->{level};
        _debug("Set level of dir to $level (general level)");
    }
    return {
        level => $level,
        category_level => $spec->{category_level},
        path => $> ? File::Spec->catfile(File::HomeDir->my_home, "log", $spec->{name}) :
            "/var/log/$spec->{name}", # XXX and on Windows?
        max_size => undef,
        max_age => undef,
        histories => undef,
        category => '',
        pattern_style => 'plain',
        pattern => undef,
        filename_pattern => 'pid-%{pid}-%Y-%m-%d-%H%M%S.txt',
    };
}

sub _parse_opt_dir {
    my ($spec, $arg) = @_;

    if (!ref($arg) && $arg && $arg !~ /^(1|yes|true)$/i) {
        $arg = {path => $arg};
    }

    _parse_opt_OUTPUT(
        kind => 'dir', default_sub => \&_default_dir,
        spec => $spec, arg => $arg,
    );
}

sub _default_screen {
    my ($spec) = @_;
    my $level = _set_level("screen", "screen");
    if (!$level) {
        $level = $spec->{level};
        _debug("Set level of screen to $level (general level)");
    }
    return {
        color => $ENV{COLOR} // (-t STDOUT),
        stderr => 1,
        level => $level,
        category_level => $spec->{category_level},
        category => '',
        pattern_style => 'script_short',
        pattern => undef,
    };
}

sub _parse_opt_screen {
    my ($spec, $arg) = @_;
    _parse_opt_OUTPUT(
        kind => 'screen', default_sub => \&_default_screen,
        spec => $spec, arg => $arg,
    );
}

sub _default_syslog {
    my ($spec) = @_;
    my $level = _set_level("syslog", "syslog");
    if (!$level) {
        $level = $spec->{level};
        _debug("Set level of syslog to $level (general level)");
    }
    return {
        level => $level,
        category_level => $spec->{category_level},
        ident => $spec->{name},
        facility => 'daemon',
        pattern_style => 'syslog',
        pattern => undef,
        category => '',
    };
}

sub _parse_opt_syslog {
    my ($spec, $arg) = @_;
    _parse_opt_OUTPUT(
        kind => 'syslog', default_sub => \&_default_syslog,
        spec => $spec, arg => $arg,
    );
}

sub _set_pattern {
    my ($s, $name) = @_;
    _debug("Setting $name pattern ...");
    unless (defined($s->{pattern})) {
        die "BUG: neither pattern nor pattern_style is defined ($name)"
            unless defined($s->{pattern_style});
        die "Unknown pattern style for $name `$s->{pattern_style}`, ".
            "use one of: ".join(", ", keys %PATTERN_STYLES)
            unless defined($PATTERN_STYLES{ $s->{pattern_style} });
        $s->{pattern} = $PATTERN_STYLES{ $s->{pattern_style} };
        _debug("Set $name pattern to `$s->{pattern}` ".
                   "(from style `$s->{pattern_style}`)");
    }
}

sub _extract_category {
    my ($ospec, $c) = @_;
    my $c0 = $c // $ospec->{category};
    my @res;
    if (ref($c0) eq 'ARRAY') { @res = @$c0 } else { @res = ($c0) }
    # replace alias with real value
    for (my $i=0; $i<@res; $i++) {
        my $c1 = $res[$i];
        my $a = $ospec->{main_spec}{category_aliases}{$c1};
        next unless defined($a);
        if (ref($a) eq 'ARRAY') {
            splice @res, $i, 1, @$a;
            $i += (@$a-1);
        } else {
            $res[$i] = $a;
        }
    }
    for (@res) {
        s/::/./g;
        # $_ = lc; # XXX do we need this?
    }
    @res;
}

sub _check_level {
    my ($level, $from) = @_;
    $level =~ /^(off|fatal|error|warn|info|debug|trace)$/i
        or die "Unknown level (from $from): $level";
    lc($1);
}

sub _set_level {
    my ($prefix, $which) = @_;
    my $p_ = $prefix ? "${prefix}_" : "";
    my $P_ = $prefix ? uc("${prefix}_") : "";
    my $F_ = $prefix ? ucfirst("${prefix}_") : "";
    my $pd = $prefix ? "${prefix}-" : "";
    my $pr = $prefix ? qr/$prefix(_|-)/ : qr//;
    my ($level, $from);

    my @label2level =([trace=>"trace"], [debug=>"debug"],
                      [verbose=>"info"], [quiet=>"error"]);

    _debug("Setting ", ($which ? "level of $which" : "general level"), " ...");
  SET:
    {
        if ($INC{"App/Options.pm"}) {
            my $key;
            for (qw/log_level loglevel/) {
                $key = $p_ . $_;
                _debug("Checking \$App::options{$key}: ", ($App::options{$key} // "(undef)"));
                if ($App::options{$key}) {
                    $level = _check_level($App::options{$key}, "\$App::options{$key}");
                    $from = "\$App::options{$key}";
                    last SET;
                }
            }
            for (@label2level) {
                $key = $p_ . $_->[0];
                _debug("Checking \$App::options{$key}: ", ($App::options{$key} // "(undef)"));
                if ($App::options{$key}) {
                    $level = $_->[1];
                    $from = "\$App::options{$key}";
                    last SET;
                }
            }
        }

        my $i = 0;
        _debug("Checking \@ARGV ...");
        while ($i < @ARGV) {
            my $arg = $ARGV[$i];
            $from = "cmdline arg $arg";
            if ($arg =~ /^--${pr}log[_-]?level=(.+)/) {
                _debug("\$ARGV[$i] looks like an option to specify level: $arg");
                $level = _check_level($1, "ARGV $arg");
                last SET;
            }
            if ($arg =~ /^--${pr}log[_-]?level$/ and $i < @ARGV-1) {
                _debug("\$ARGV[$i] and \$ARGV[${\($i+1)}] looks like an option to specify level: $arg ", $ARGV[$i+1]);
                $level = _check_level($ARGV[$i+1], "ARGV $arg ".$ARGV[$i+1]);
                last SET;
            }
            for (@label2level) {
                if ($arg =~ /^--${pr}$_->[0](=(1|yes|true))?$/i) {
                    _debug("\$ARGV[$i] looks like an option to specify level: $arg");
                    $level = $_->[1];
                    last SET;
                }
            }
            $i++;
        }

        for (qw/LOG_LEVEL LOGLEVEL/) {
            my $key = $P_ . $_;
            _debug("Checking environment variable $key: ", ($ENV{$key} // "(undef)"));
            if ($ENV{$key}) {
                $level = _check_level($ENV{$key}, "ENV $key");
                $from = "\$ENV{$key}";
                last SET;
            }
        }
        for (@label2level) {
            my $key = $P_ . uc($_->[0]);
            _debug("Checking environment variable $key: ", ($ENV{$key} // "(undef)"));
            if ($ENV{$key}) {
                $level = $_->[1];
                $from = "\$ENV{$key}";
                last SET;
            }
        }

        no strict 'refs';
        for ("${F_}Log_Level", "${P_}LOG_LEVEL", "${p_}log_level",
             "${F_}LogLevel",  "${P_}LOGLEVEL",  "${p_}loglevel") {
            my $varname = "main::$_";
            _debug("Checking variable \$$varname: ", ($$varname // "(undef)"));
            if ($$varname) {
                $from = "\$$varname";
                $level = _check_level($$varname, "\$$varname");
                last SET;
            }
        }
        for (@label2level) {
            for my $varname (
                "main::$F_" . ucfirst($_->[0]),
                "main::$P_" . uc($_->[0])) {
                _debug("Checking variable \$$varname: ", ($$varname // "(undef)"));
                if ($$varname) {
                    $from = "\$$varname";
                    $level = $_->[1];
                    last SET;
                }
            }
        }
    }

    _debug("Set ", ($which ? "level of $which" : "general level"), " to $level (from $from)") if $level;
    return $level;
}

# return the lower level (e.g. _min_level("debug", "INFO") -> INFO
sub _min_level {
    my ($l1, $l2) = @_;
    my %vals = (OFF=>99,
                FATAL=>6, ERROR=>5, WARN=>4, INFO=>3, DEBUG=>2, TRACE=>1);
    $vals{uc($l1)} > $vals{uc($l2)} ? $l2 : $l1;
}

sub _export_logger {
    my ($caller) = @_;
    my $log_for_caller = Log::Any->get_logger(category => $caller);
    my $varname = "$caller\::log";
    no strict 'refs';
    *$varname = \$log_for_caller;
}

sub _debug {
    return unless $ENV{LOGANYAPP_DEBUG};
    print $dbg_ctx, ": " if $dbg_ctx;
    print @_, "\n";
}

sub import {
    my ($self, @args) = @_;
    my $caller = caller();
    _parse_args(\@args, $caller);
    $init_args = \@args;
}

INIT {
    my $caller = caller();
    init($init_args, $caller);
}


=head1 FAQ

=head2 What's the benefit of using Log::Any::App?

You get all the benefits of Log::Any, as what Log::Any::App does is just wrap
Log::Any and L<Log::Log4perl> with some nice defaults. It provides you with an
easy way to consume Log::Any logs and customize level/some other options via
various ways.

You still produce logs with Log::Any so later should portions of your application
code get refactored into modules, you don't need to change the logging part. And
if your application becomes more complex and Log::Any::App doesn't suffice your
custom logging needs anymore, you can just replace 'use Log::Any::App' line with
something more adequate.

=head2 And what's the benefit of using Log::Any?

This is better described in the Log::Any documentation itself, but in short:
Log::Any frees your module users to use whatever logging framework they want. It
increases the reusability of your modules.

=head2 Do I need Log::Any::App if I am writing modules?

No, if you write modules just use Log::Any.

=head2 Why use Log4perl?

Log::Any::App uses the Log4perl adapter to display the logs because it is mature,
flexible, featureful. The other alternative adapter is Log::Dispatch, but you can
use Log::Dispatch::* output modules in Log4perl and (currently) not vice versa.

Other adapters might be considered in the future, for now I'm fairly satisfied
with Log4perl.

Note that producing logs are still done with Log::Any as usual and not tied to
Log4perl in any way.

=head2 How do I create extra logger objects?

The usual way as with Log::Any:

 my $other_log = Log::Any->get_logger(category => $category);

=head2 My needs are not met by the simple configuration system of Log::Any::App!

You can use Log4perl adapter directly and write your own Log4perl configuration
(or even other adapters). Log::Any::App is meant for quick and simple logging
output needs anyway (but do tell me if your logging output needs are reasonably
simple and should be supported by Log::Any::App).

=head1 BUGS/TODOS

Need to provide appropriate defaults for Windows/other OS.

Probably: SCREEN0_DEBUG, --file1-log-level, etc.

=head1 SEE ALSO

L<Log::Any>

L<Log::Log4perl>

=cut

1;
