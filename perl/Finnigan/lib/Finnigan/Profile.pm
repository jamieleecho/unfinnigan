package Finnigan::Profile;

use strict;
use warnings;

use Finnigan;
use base 'Finnigan::Decoder';


sub decode {
  my ($class, $stream, $layout) = @_;

  my $preamble = [
		  "first value" => ['d', 'Float64'],
		  "step"        => ['d', 'Float64'],
		  "peak count"  => ['V', 'UInt32'],
		  "nbins"       => ['V', 'UInt32'],
		 ];

  my $self = bless Finnigan::Decoder->read($stream, $preamble), $class;
  $self->iterate_object($stream, $self->peak_count, chunks => 'Finnigan::ProfileChunk', $layout);
  return $self;
}

sub peak_count {
  shift->{data}->{"peak count"}->{value};
}

sub nbins {
  shift->{data}->{"nbins"}->{value};
}

sub first_value {
  shift->{data}->{"first value"}->{value};
}

sub step {
  shift->{data}->{"step"}->{value};
}

sub chunks {
  shift->{data}->{"chunks"}->{value};
}
sub chunk { # a syntactic eye-sore remover
  shift->{data}->{"chunks"}->{value};
}

sub converter {
  shift->{converter}
}

sub set_converter {
  my ($self, $converter) = @_;
  $self->{converter} = $converter;
}

sub inverse_converter {
  shift->{"inverse converter"}
}

sub set_inverse_converter {
  my ($self, $converter) = @_;
  $self->{"inverse converter"} = $converter;
}

sub bins {
  my ($self, $range) = @_;
  my @list;
  my $start = $self->first_value;
  my $step = $self->step;
  foreach my $i ( 0 .. $self->peak_count - 1 ) {
    my $chunk = $self->chunk->[$i];
    my $x = $start + ($self->chunk->[$i]->first_bin - 1) * $step;
    foreach my $j ( 0 .. $self->chunk->[$i]->nbins - 1) {
      $x += $step;
      my $x_conv = $self->converter ? &{$self->converter}($x) : $x;
      if ( $range ) {
	next unless $x_conv >= $range->[0] and $x_conv <= $range->[1];
      }
      push @list, [$x_conv, $self->chunk->[$i]->signal->[$j]];
    }
  }
  return \@list;
}


sub print_bins {
  my ($self, $range, $restore_zeroes) = @_;
  my @list;
  my $start = $self->first_value;
  my $step = $self->step;
  my $fill_from = 0;
  foreach my $i ( 0 .. $self->peak_count - 1 ) {
    my $chunk = $self->chunk->[$i];
    my $first_bin = $chunk->first_bin - 1;
    if ( $restore_zeroes ) {
      
    }
    my $x = $start + $first_bin * $step;
    foreach my $j ( 0 .. $chunk->nbins - 1) {
      $x += $step;
      my $x_conv = $self->converter ? &{$self->converter}($x) : $x;
      if ( $range ) {
	next unless $x_conv >= $range->[0] and $x_conv <= $range->[1];
      }
      print "$x_conv\t" . $chunk->signal->[$j] . "\n";
    }
  }
  return \@list;
}


sub find_precursor_peak {
  my ($self, $query) = @_;

  my $raw_query = &{$self->inverse_converter}($query);

  my $start = $self->first_value;
  my $step = $self->step;

  # find the closest point
  my $closest = my $second_closest = { point => {chunk => 0, n => 0}, dist => 10e6 };
  foreach my $i ( 0 .. $self->peak_count - 1 ) {
    my $x = $start + ($self->chunk->[$i]->first_bin - 1) * $step;
    foreach my $j ( 0 .. $self->chunk->[$i]->nbins - 1) {
      $x += $step;
      my $dist1 = $raw_query - $x;
      my $dist2 = $x - $raw_query;
      if ( $dist1 >= 0 and $dist1 < $closest->{dist}) {
        $closest = { point => {chunk => $i, n => $j}, dist => $dist1 };
      }
      if ( $dist2 >= 0 and $dist2 < $second_closest->{dist}) {
        $second_closest = { point => {chunk => $i, n => $j}, dist => $dist2 };
      }
    }
  }

  die "could not find the precursor peak for M/z $query; the nearest candidate is $closest->{dist} a.u. away"  if $closest->{dist} > 0.5;
  my $i = $closest->{point}->{chunk};
  my $j = $closest->{point}->{n};
  my $point1 = {
                mz => &{$self->converter}($start + ($self->chunk->[$i]->first_bin + $j - 1) * $step),
                intensity => $self->chunk->[$i]->signal->[$j]
               };
  $i = $second_closest->{point}->{chunk};
  $j = $second_closest->{point}->{n};
  my $point2 = {
                mz => &{$self->converter}($start + ($self->chunk->[$i]->first_bin + $j - 1) * $step),
                intensity => $self->chunk->[$i]->signal->[$j]
               };
  return $point1->{intensity} > $point2->{intensity} ? $point1 : $point2;
}

1;
__END__

=head1 NAME

Finnigan::ScanIndexEntry -- decoder for ScanIndexEntry, a linked list item pointing to scan data

=head1 SYNOPSIS

  use Finnigan;
  my $entry = Finnigan::ScanIndexEntry->decode(\*INPUT);
  say $entry->offset; # returns an offset from the start of scan data stream 
  say $entry->data_size;
  $entry->dump;

=head1 DESCRIPTION

ScanIndexEntry is a static (fixed-size) structure containing the
pointer to a scan, the scan's data size and some auxiliary information
about the scan.

ScanIndexEntry elements seem to form a linked list. Each
ScanIndexEntry contains the index of the next entry.

Although in all observed instances the scans were sequential and their
indices could be ignored, it may not always be the case.

It is not clear whether scan index numbers start at 0 or at 1. If they
start at 0, the list link index must point to the next item. If they
start at 1, then "index" will become "previous" and "next" becomes
"index" -- the list will be linked from tail to head. Although
observations are lacking, I am inclined to interpret it as a
forward-linked list, simply from common sense.


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::RunHeader

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
