use strict;
use warnings;
package App::Uni;
# ABSTRACT: command-line utility to find or display Unicode characters
$App::Uni::VERSION = '9.001';
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
    die join qq{\n  }, "usage:",
      "uni SEARCH-TERMS...    - find codepoints with matching names or values",
      "uni [-s] ONE-CHARACTER - print the codepoint and name of one character",
      "uni -n SEARCH-TERMS... - find codepoints with matching names",
      "uni -c STRINGS...      - print out the codepoints in a string",
      "uni -u CODEPOINTS...   - look up and print hex codepoints\n";
  }

  my $todo;
  $todo = \&do_explode    if @argv && $argv[0] eq '-c';
  $todo = \&do_u_numbers  if @argv && $argv[0] eq '-u';
  $todo = \&do_names      if @argv && $argv[0] eq '-n';
  $todo = \&do_single     if @argv && $argv[0] eq '-s';

  shift @argv if $todo;

  if (grep /\A-./, @argv) {
    die "uni: only one swich allowed!\n" if $todo;
    die "uni: unknown switch $argv[0]\n";
  }

  $todo //= @argv == 1 && length $argv[0] == 1
          ? \&do_single
          : \&do_dwim;

  $todo->(\@argv);
}

sub do_single {
  print_chars(@_);
}

sub do_explode {
  print_chars( explode_strings(@_) );
}

sub explode_strings {
  my ($strings) = @_;

  my @chars;

  while (my $str = shift @$strings) {
    push @chars, split '', $str;
    push @chars, undef if @$strings;
  }

  return \@chars;
}

sub do_u_numbers {
  print_chars( chars_by_u_numbers(@_) );
}

sub print_chars {
  my ($chars) = @_;

  for my $c (@$chars) {
    unless (defined $c) { print "\n"; next }

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

sub chars_by_u_numbers {
  my ($points) = @_;
  my @chars = map {; /\A(?:u\+)?(.+)/; chr hex $1 } @$points;
  return \@chars;
}

sub do_names {
  my ($terms) = @_;

  print_chars( chars_by_name( $terms ) );
}

sub chars_by_name {
  my ($input_terms, $arg) = @_;
  my @terms = map {; { pattern => s{\A/(.+)/\z}{$1} ? qr/$_/i : qr/\b$_\b/i } }
              @$input_terms;

  if ($arg && $arg->{match_codepoints}) {
    for (0 .. $#terms) {
      $terms[$_]{ord} = hex $input_terms->[$_]
        if $input_terms->[$_] =~ /\A[0-9A-Fa-f]+\z/;
    }
  }

  my $corpus = require 'unicore/Name.pl';
  die "somebody beat us here" if $corpus eq '1';

  my @lines = split /\cJ/, $corpus;
  my @chars;

  my %seen;
  LINE: for my $line (@lines) {
    my $i = index($line, "\t");
    next if rindex($line, " ", $i) >= 0; # no sequences

    my $name = substr($line, $i+1);
    my $ord  = hex substr($line, 0, $i);

    for (@terms) {
      next LINE unless $name =~ $_->{pattern}
                or     defined $_->{ord} && $_->{ord} == $ord;
    }

    my $c = chr hex substr $line, 0, $i;
    next if $seen{$c}++;
    push @chars, chr hex substr $line, 0, $i;
  }

  return \@chars;
}

sub smerge {
  my %splat = map {; $_ => 1 } map { @$_ } @_;
  return [ sort keys %splat ];
}

sub do_dwim {
  my ($argv) = @_;
  my $chars = chars_by_name($argv, { match_codepoints => 1 });
  print_chars($chars);
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

App::Uni - command-line utility to find or display Unicode characters

=head1 VERSION

version 9.001

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
