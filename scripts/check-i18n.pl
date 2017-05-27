#!/usr/bin/perl

use strict;
use warnings;
use Cwd 'abs_path';

# script which checks how out of sync the i18ns are drifting

# example i18n format:
#   "%(oneUser)sleft": "%(oneUser)sleft",

$|=1;

$0 =~ /^(.*\/)/;
my $i18ndir = abs_path($1."/../src/i18n/strings");
my $srcdir = abs_path($1."/../src");

my $en = read_i18n($i18ndir."/en_EN.json");

my $src_strings = read_src_strings($srcdir);

print "Checking strings in src\n";
foreach my $tuple (@$src_strings) {
    my ($s, $file) = (@$tuple);
    if (!$en->{$s}) {
        if ($en->{$s . '.'}) {
            printf ("%50s %24s\t%s\n", $file, "en_EN has fullstop!", $s);
        }
        else {
            $s =~ /^(.*)\.?$/;
            if ($en->{$1}) {
                printf ("%50s %24s\t%s\n", $file, "en_EN lacks fullstop!", $s);
            }
            else {
                printf ("%50s %24s\t%s\n", $file, "Translation missing!", $s);
            }
        }
    }
}

opendir(DIR, $i18ndir) || die $!;
my @files = readdir(DIR);
closedir(DIR);
foreach my $lang (grep { -f "$i18ndir/$_" && !/en_EN\.json/ } @files) {
    print "\nChecking $lang\n";

    my $map = read_i18n($i18ndir."/".$lang);
    my $count = 0;

    foreach my $k (sort keys %$map) {
        if ($en->{$k}) {
            if ($map->{$k} eq $k) {
                printf ("%10s %24s\t%s\n", $lang, "Untranslated string?", "$k");
            }
            $count++;
        }
        else {
            if ($en->{$k . "."}) {
                printf ("%10s %24s\t%s\n", $lang, "en_EN has fullstop!", "$k");
                next;
            }

            $k =~ /^(.*)\.?$/;
            if ($en->{$1}) {
                printf ("%10s %24s\t%s\n", $lang, "en_EN lacks fullstop!", "$k");
                next;
            }

            printf ("%10s %24s\t%s\n", $lang, "Not present in en_EN", "$k");
        }
    }

    printf ("$count/" . (scalar keys %$en) . " strings translated\n");
}

sub read_i18n {
    my $path = shift;
    my $map = {};

    open(FILE, "<", $path) || die $!;
    while(<FILE>) {
        if ($_ =~ m/^(\s+)"(.*?)"(: *)"(.*?)"(,?)$/) {
            my ($indent, $src, $colon, $dst, $comma) = ($1, $2, $3, $4, $5);
            $src =~ s/\\"/"/g;
            $dst =~ s/\\"/"/g;
            $map->{$src} = $dst;
        }
    }
    close(FILE);

    return $map;
}

sub read_src_strings {
    my $path = shift;

    use File::Find;
    use File::Slurp;

    my $strings = [];

    my @files;
    find( sub { push @files, $File::Find::name if (-f $_ && /\.jsx?$/) }, $path );
    foreach my $file (@files) {
        my $src = read_file($file);
        $src =~ s/'\s*\+\s*'//g;
        $src =~ s/"\s*\+\s*"//g;

        $file =~ s/^.*\/src/src/;
        while ($src =~ /_t\(\s*'(.*?[^\\])'/sg) {
            my $s = $1;
            $s =~ s/\\'/'/g;
            push @$strings, [$s, $file];
        }
        while ($src =~ /_t\(\s*"(.*?[^\\])"/sg) {
            push @$strings, [$1, $file];
        }
    }

    return $strings;
}