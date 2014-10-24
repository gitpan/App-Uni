use strict;
use warnings;
package App::Uni;
# ABSTRACT: command-line utility to find or display Unicode characters
$App::Uni::VERSION = '9.000';
#pod =encoding utf8
#pod
#pod =head1 NAME
#pod
#pod App::Uni - Command-line utility to grep UnicodeData.txt
#pod
#pod =head1 SYNOPSIS
#pod
#pod     $ uni smiling face
#pod     263A ☺ WHITE SMILING FACE
#pod     263B ☻ BLACK SMILING FACE
#pod
#pod     $ uni ☺
#pod     263A ☺ WHITE SMILING FACE
#pod
#pod     # Only on Perl 5.14+
#pod     $ uni wry
#pod     1F63C <U+1F63C> CAT FACE WITH WRY SMILE
#pod
#pod =head1 DESCRIPTION
#pod
#pod This module installs a simple program, F<uni>, that helps grepping through
#pod the Unicode database included in the current Perl 5 installation.
#pod
#pod For information on how to use F<uni> consult the L<uni> documentation.
#pod
#pod =head1 ACKNOWLEDGEMENTS
#pod
#pod This is a re-implementation of a program written by Audrey Tang in Taiwan.  I
#pod used that program for years before deciding I wanted to add a few features,
#pod which I did by rewriting from scratch.
#pod
#pod That program, in turn, was a re-implementation of a same-named program Larry
#pod copied to me, which accompanied Audrey for years.  However, that program was
#pod lost during a hard disk failure, so she coded it up from memory.
#pod
#pod Thank-you, Larry, for everything. ♡
#pod
#pod =cut

use 5.10.0; # for \v
use warnings;

use charnames ();
use Unicode::GCString;

sub run {
  my ($class, @argv) = @_;

  if (! @argv or $argv[0] eq '--help') {
    die join qq{\n}, "usage:",
      "  uni ONE-CHARACTER    - print the codepoint and name of character",
      "  uni SEARCH-TERMS...  - search for codepoints with matching names",
      "  uni -c STRINGS...    - print out the codepoints in a string",
      "  uni -u CODEPOINTS... - look up and print hex codepoints\n";
  }

  my $todo;
  $todo = \&split_string if @argv && $argv[0] eq '-c';
  $todo = \&codepoints   if @argv && $argv[0] eq '-u';

  shift @argv if $todo;

  if (grep /\A-./, @argv) {
    die "uni: only one swich allowed!\n" if $todo;
    die "uni: unknown switch $argv[0]\n";
  }

  $todo //= @argv == 1 && length $argv[0] == 1
          ? \&one_char
          : \&search_chars;

  $todo->(@argv);
}

sub one_char {
  print_chars(@_);
}

sub split_string {
  my (@args) = @_;

  while (my $str = shift @args) {
    my @chars = split '', $str;
    print_chars(@chars);

    say '' if @args;
  }
}

sub print_chars {
  my (@chars) = @_;
  for my $c (@chars) {

    my $c2 = Unicode::GCString->new($c);
    my $l  = $c2->columns;

    # I'm not 100% sure why I need this in all cases.  It would make sense in
    # some, since for example COMBINING GRAVE beginning a line becomes its
    # own extended grapheme cluster (right?), but why does INVISIBLE TIMES at
    # the beginning of a line take up a column despite being printing width
    # zero?  The world may never know.  Until Tom tells me.
    # -- rjbs, 2014-10-04
    $l = 1 if $l == 0; # ???

    # Yeah, probably there's some insane %*0s$ invocation of printf to use
    # here, but... just no. -- rjbs, 2014-10-04
    (my $p = $c) =~ s/\v/ /g;
    $p .= (' ' x (2 - $l));

    my $chr  = ord($c);
    my $name = charnames::viacode($chr);
    printf "%s- U+%05X - %s\n", $p, $chr, $name;
  }
}

sub codepoints {
  my (@points) = @_;

  my @chars = map {; chr hex s/\Au\+//r } @points;
  print_chars(@chars);
}

sub search_chars {
  my @terms = map {; s{\A/(.+)/\z}{$1} ? qr/$_/i : qr/\b$_\b/i } @_;

  my $corpus = require 'unicore/Name.pl';
  die "somebody beat us here" if $corpus eq '1';

  my @lines = split /\cJ/, $corpus;
  my @chars;

  my %seen;
  LINE: for my $line (@lines) {
    my $i = index($line, "\t");
    next if rindex($line, " ", $i) >= 0; # no sequences

    $line =~ $_ || next LINE for @terms;

    my $c = chr hex substr $line, 0, $i;
    next if $seen{$c}++;
    push @chars, chr hex substr $line, 0, $i;
  }

  print_chars(@chars);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Uni - command-line utility to find or display Unicode characters

=head1 VERSION

version 9.000

=head1 SYNOPSIS

    $ uni smiling face
    263A ☺ WHITE SMILING FACE
    263B ☻ BLACK SMILING FACE

    $ uni ☺
    263A ☺ WHITE SMILING FACE

    # Only on Perl 5.14+
    $ uni wry
    1F63C <U+1F63C> CAT FACE WITH WRY SMILE

=head1 DESCRIPTION

This module installs a simple program, F<uni>, that helps grepping through
the Unicode database included in the current Perl 5 installation.

For information on how to use F<uni> consult the L<uni> documentation.

=head1 NAME

App::Uni - Command-line utility to grep UnicodeData.txt

=head1 ACKNOWLEDGEMENTS

This is a re-implementation of a program written by Audrey Tang in Taiwan.  I
used that program for years before deciding I wanted to add a few features,
which I did by rewriting from scratch.

That program, in turn, was a re-implementation of a same-named program Larry
copied to me, which accompanied Audrey for years.  However, that program was
lost during a hard disk failure, so she coded it up from memory.

Thank-you, Larry, for everything. ♡

=head1 AUTHOR

Ricardo Signes <rjbs@cpan.org>

=head1 COPYRIGHT AND LICENSE


Ricardo Signes has dedicated the work to the Commons by waiving all of his
or her rights to the work worldwide under copyright law and all related or
neighboring legal rights he or she had in the work, to the extent allowable by
law.

Works under CC0 do not require attribution. When citing the work, you should
not imply endorsement by the author.

=cut
