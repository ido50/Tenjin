package Tenjin::Util;

use strict;
use warnings;

use Fcntl qw/:flock/;
use Encode;
use HTML::Entities;

sub new {
	bless {}, shift;
}

sub read_file {
	my ($self, $filename, $lock_required) = @_;

	open(IN, $filename) or die("Tenjin::Util: Can't open $filename for reading: $!");
	binmode(IN);
	flock(IN, LOCK_SH) if ($lock_required);

	read(IN, my $content, -s $filename);

	close(IN);

	return $content;
}

sub write_file {
	my ($self, $filename, $content, $lock_required) = @_;

	open(OUT, ">$filename") or die("Tenjin::Util: \"Can't open $filename for writing: $!\"");
	binmode(OUT);
	flock(OUT, LOCK_EX) if $lock_required;
	print OUT $content;
	close(OUT);
}

sub expand_tabs {
	my ($self, $str, $tabwidth) = @_;

	$tabwidth = 8 unless defined($tabwidth);
	my $s = '';
	my $pos = 0;
	while ($str =~ /.*?\t/sg) { # /(.*?)\t/ may be slow
		my $end = $+[0];
		my $text = substr($str, $pos, $end - 1 - $pos);
		my $n = rindex($text, "\n");
		my $col = $n >= 0 ? length($text) - $n - 1 : length($text);
		$s .= $text;
		$s .= ' ' x ($tabwidth - $col % $tabwidth);
		$pos = $end;
	}
	my $rest = substr($str, $pos);
	return $s;
}


sub _p {
	"<`\#$_[0]\#`>";
}


sub _P {
	"<`\$$_[0]\$`>";
}


sub _decode_params {
	my ($self, $s) = @_;

	return '' unless $s;

	$s =~ s/%3C%60%23(.*?)%23%60%3E/'[=='.$self->decode_url($1).'=]'/ge;
	$s =~ s/%3C%60%24(.*?)%24%60%3E/'[='.$self->decode_url($1).'=]'/ge;
	$s =~ s/&lt;`\#(.*?)\#`&gt;/'[=='.$self->unescape_xml($1).'=]'/ge;
	$s =~ s/&lt;`\$(.*?)\$`&gt;/'[='.$self->unescape_xml($1).'=]'/ge;
	$s =~ s/<`\#(.*?)\#`>/[==$1=]/g;
	$s =~ s/<`\$(.*?)\$`>/[=$1=]/g;

	return $s;
}

sub escape_xml {
	encode_entities($_[1], '<>&"\'');
}

sub unescape_xml {
	decode_entities($_[1]);
}

sub encode_url {
	my ($self, $s) = @_;

	$s =~ s/([^-A-Za-z0-9_.\/])/sprintf("%%%02X", ord($1))/sge;
	$s =~ tr/ /+/;
	return $s;
}

sub decode_url {
	my ($self, $s) = @_;

	$s =~ s/\%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/sge;
	return $s;
}

sub checked {
	$_[1] ? ' checked="checked"' : '';
}

sub selected {
	$_[1] ? ' selected="selected"' : '';
}

sub disabled {
	$_[1] ? ' disabled="disabled"' : '';
}

sub nl2br {
	my ($self, $text) = @_;

	$text =~ s/(\r?\n)/<br \/>$1/g;
	return $text;
}

sub text2html {
	my ($self, $text) = @_;

	$self->nl2br($self->escape_xml($text));
}

sub tagattr {
	my ($self, $name, $expr, $value) = @_;

	return '' unless $expr;
	$value = $expr unless defined($value);
	return " $name=\"$value\"";
}

sub tagattrs {
	my ($self, %attrs) = @_;

	my $s = '';
	while (my ($k, $v) = each %attrs) {
		$s .= " $k=\"".$self->escape_xml($v)."\"" if defined $v;
	}
	return $s;
}

## ex.
##   my $cycle = new_cycle('red', 'blue');
##   print $cycle->();  #=> 'red'
##   print $cycle->();  #=> 'blue'
##   print $cycle->();  #=> 'red'
##   print $cycle->();  #=> 'blue'
sub new_cycle {
	my $self = shift;

	my $i = 0;
	sub { $_[$i++ % scalar @_] };  # returns
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::Util - Utility methods for Tenjin.

=head1 SYNOPSIS

	used internally.

=head1 SEE ALSO

L<Tenjin>.

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>.
The CPAN version was tidied and CPANized from the original 0.0.2 source (with later updates from Makoto Kuwata's tenjin github repository) by Ido Perlmuter E<lt>ido@ido50.netE<gt>.

=head1 LICENSE AND COPYRIGHT

Tenjin is licensed under the MIT license.

	Copyright (c) 2007-2010 the aforementioned authors.

	Permission is hereby granted, free of charge, to any person obtaining
	a copy of this software and associated documentation files (the
	"Software"), to deal in the Software without restriction, including
	without limitation the rights to use, copy, modify, merge, publish,
	distribute, sublicense, and/or sell copies of the Software, and to
	permit persons to whom the Software is furnished to do so, subject to
	the following conditions:

	The above copyright notice and this permission notice shall be
	included in all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
	EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
	MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
	NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
	LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
	OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
	WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

=cut
