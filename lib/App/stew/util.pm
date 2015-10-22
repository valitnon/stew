package App::stew::util;

use strict;
use warnings;

use base 'Exporter';

our @EXPORT_OK = qw(info debug error slurp_file write_file cmd _chdir _mkpath _copy _unlink _tree _tree_diff);

use File::Find qw(find);
use Carp qw(croak);
use File::Copy qw(copy);
use File::Path qw(mkpath rmtree);

sub slurp_file {
    my ($file) = @_;

    local $/;
    open my $fh, '<', $file or error("Can't read file '$file': $!");
    return <$fh>;
}

sub write_file {
    my ($file, $content) = @_;

    open my $fh, '>', $file or error("Can't write file '$file': $!");
    print $fh $content;
    close $fh;
}

sub debug {
    print STDERR @_, "\n" if $ENV{STEW_LOG_LEVEL};

    _log(@_);
}

sub info {
    _log(@_);
    warn join(' ', @_) . "\n";
}

sub error {
    _log(@_);
    croak("ERROR: " . join(' ', @_));
}

sub _chdir {
    my ($dir) = @_;

    debug(qq{Entering '$dir'});
    die "Directory '$dir' does not exist" unless -d $dir;
    chdir($dir);
}

sub _mkpath {
    my ($dir) = @_;

    debug(qq{Creating '$dir'});
    mkpath($dir);
}

sub _copy {
    my ($from, $to) = @_;

    debug(qq{Copying '$from' -> '$to'});
    copy($from, $to);
}

sub _unlink {
    my ($file) = @_;

    debug(qq{Unlinking '$file'});
    unlink($file);
}

sub cmd {
    return unless @_;

    my $cmd = join ' && ', @_;

    $cmd = "sh -c \"$cmd 2>&1\" 2>&1 >> $ENV{STEW_LOG_FILE}";

    debug($cmd);

    #unless ($opt_dry_run) {
    my $exit = system($cmd);

    error("Command failed: $cmd") if $exit;

    #}
}

sub _log {
    open my $fh, '>>', $ENV{STEW_LOG_FILE}
      or die "Can't open logfile '$ENV{STEW_LOG_FILE}': $!";
    print $fh @_, "\n";
    close $fh;
}

sub _tree {
    my ($dir, $prefix) = @_;

    my @tree;
    find(
        sub {
            return unless -f $_;

            my $name = $File::Find::name;

            if ($prefix) {
                $name =~ s{^$prefix/?}{};
            }

            push @tree, $name;
        },
        $dir
    );

    return [sort @tree];
}

sub _tree_diff {
    my ($tree1, $tree2) = @_;

    my @diff;
    my $diff_pos = 0;

    for (my $pos = 0; $pos < @$tree1; $pos++) {
        while ($pos < @$tree1
            && $diff_pos < @$tree2
            && $tree1->[$pos] eq $tree2->[$diff_pos])
        {
            $pos++;
            $diff_pos++;
        }

        while ($pos < @$tree1
            && $diff_pos < @$tree2
            && $tree1->[$pos] ne $tree2->[$diff_pos])
        {
            push @diff, $tree2->[$diff_pos];
            $diff_pos++;
        }
    }

    while ($diff_pos < @$tree2) {
        push @diff, $tree2->[$diff_pos];
        $diff_pos++;
    }

    return \@diff;
}

1;