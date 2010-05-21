package Finnigan::MethodFile;

use strict;
use warnings;

use Finnigan;
use base 'Finnigan::Decoder';
use Data::Dumper;


sub decode {
  my ($class, $stream, $version) = @_;

  my @fields = (
                "header"      => ['object', 'Finnigan::FileHeader'],
                "file size"        => ['V',      'UInt32'],
                "orig file name"   => ['varstr', 'PascalStringWin32'],
                "n"                => ['V',      'UInt32'],
               );

  my $self = Finnigan::Decoder->read($stream, \@fields, $version);
  bless $self, $class;

  if ( $self->n ) { # this is a hack, because I don't have an iterate_hash() method
    # the tags come in pairs, so retreive them later with a method
    $self->iterate_scalar($stream, 2*$self->n, "instrument tag" => ['varstr', 'PascalStringWin32']);
  }

  $self->SUPER::decode($stream, ["ms ole data" => ['object', 'Finnigan::OLE2File']]);

  return $self;
}

sub n {
  shift->{data}->{n}->{value};
}

sub file_size {
  shift->{data}->{"file size"}->{value};
}

sub ms_ole_data {
  shift->{data}->{"ms ole data"}->{value};
}

sub header {
  shift->{data}->{"header"}->{value};
}

sub instrument_tag {
  shift->{data}->{"instrument tag"}->{value};
}

sub instrument {
  my ($self, $i) = @_;
  my $n = $self->n;
  die "insrument index cannot be 0" if $i == 0;
  die "instrument index cannot be greater than $n" if $i > $n;
  $i--;
  return @{$self->instrument_tag}[2*$i .. 2*$i + 1];
}

sub time1 {
  Finnigan::Decoder::from_struct_tm(shift->{tree}->{Time1st});
}

sub time2 {
  Finnigan::Decoder::from_struct_tm(shift->{tree}->{Time2nd});
}

1;
__END__

=head1 NAME

Finnigan::MethodFile -- a decoder for MethodFile, the binary data part of RawFileInfo

=head1 SYNOPSIS

  use Finnigan;
  my $file_info = Finnigan::MethodFile->decode(\*INPUT);
  say $file_info->run_header_addr;
  $file_info->dump;

=head1 DESCRIPTION

This fixed-size structure is a binary preamble to RawFileInfo, and it
contains an unpacked representation of a UTC date (apparently, the
file creation date), a set of unknown numbers, and most importantly,
the more modern versions of this structure contain the pointers to
ScanData? and to RunHeader, which in turn stores pointers to all data
streams in the file.

The older version of this structure did not extend beyond the date stamp.


=head2 EXPORT

None

=head1 SEE ALSO

Finnigan::RawFileInfo

=head1 AUTHOR

Gene Selkov, E<lt>selkovjr@gmail.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Gene Selkov

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.10.0 or,
at your option, any later version of Perl 5 you may have available.


=cut
