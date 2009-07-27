package Tenjin::Util;

use Fcntl qw/:flock/;

use strict;

sub read_file {
	my ($filename, $lock_required) = @_;

	open(IN, $filename) or die("Tenjin::Util: Can't open $filename for reading: $!");
	binmode(IN);
	flock(IN, LOCK_SH) if ($lock_required);

	my $content = '';
	my $size = 8192;
	my @buf = ();

	while (read(IN, my $data, $size)) {
		push(@buf, $data);
	}

	close(IN);

	return $#buf == 0 ? $buf[0] : join('', @buf);
}


sub write_file {
	my ($filename, $content, $lock_required) = @_;

	open(OUT, ">$filename") or die("Tenjin::Util: Can't open $filename for writing: $!");
	binmode(OUT);
	flock(OUT, LOCK_EX) if $lock_required;
	print OUT $content;
	close(OUT);
}


sub expand_tabs {
	my ($str, $tabwidth) = @_;

	$tabwidth = 8 unless defined($tabwidth);
	my @buf = ();
	my $pos = 0;
	while ($str =~ /.*?\t/sg) { # /(.*?)\t/ may be slow
		my $end = $+[0];
		my $text = substr($str, $pos, $end - 1 - $pos);
		my $n = rindex($text, "\n");
		my $col = $n >= 0 ? length($text) - $n - 1 : length($text);
		push(@buf, $text, ' ' x ($tabwidth - $col % $tabwidth));
		$pos = $end;
	}
	my $rest = substr($str, $pos);
	push(@buf, $rest) if $rest;
	return join('', @buf);
}


sub _p {
	my ($arg) = @_;
	return "<`\#$arg\#`>";
}


sub _P {
	my ($arg) = @_;
	return "<`\$$arg\$`>";
}


sub _decode_params {
	my ($s) = @_;

	#$s = '' . $s;
	return '' unless $s;

	$s =~ s/%3C%60%23(.*?)%23%60%3E/'[=='.Tenjin::Helper::Html::decode_url($1).'=]'/ge;
	$s =~ s/%3C%60%24(.*?)%24%60%3E/'[='.Tenjin::Helper::Html::decode_url($1).'=]'/ge;
	$s =~ s/&lt;`\#(.*?)\#`&gt;/'[=='.Tenjin::Helper::Html::unescape_xml($1).'=]'/ge;
	$s =~ s/&lt;`\$(.*?)\$`&gt;/'[='.Tenjin::Helper::Html::unescape_xml($1).'=]'/ge;
	$s =~ s/<`\#(.*?)\#`>/[==$1=]/g;
	$s =~ s/<`\$(.*?)\$`>/[=$1=]/g;

	return $s;
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

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>. Version 0.03 was tidied and CPANized from the original 0.0.2 source by Ido Perelmutter E<lt>ido50@yahoo.comE<gt>.

=head1 COPYRIGHT & LICENSE

Tenjin is licensed under the MIT license.

	Copyright (c) 2007-2009 the aforementioned authors.

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
