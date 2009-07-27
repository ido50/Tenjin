package Tenjin::HTML;

use strict;

our %_escape_table = ( '&'=>'&amp;', '<'=>'&lt;', '>'=>'&gt;', '"'=>'&quot;', "'"=>'&#039;');
our %_unescape_table = ('lt'=>'<', 'gt'=>'>', 'amp'=>'&', 'quot'=>'"', '#039'=>"'");

sub escape_xml {
	my ($s) = @_;

	$s =~ s/[&<>"]/$_escape_table{$&}/ge if ($s);
	return $s;
}

sub unescape_xml {
	my ($s) = @_;

	$s =~ tr/+/ /;
	$s =~ s/&(lt|gt|amp|quot|#039);/$_unescape_table{$1}/ge if ($s);
	return $s;
}

sub encode_url {
	my ($s) = @_;

	$s =~ s/([^-A-Za-z0-9_.\/])/sprintf("%%%02X", ord($1))/sge;
	$s =~ tr/ /+/;
	return $s;
}

sub decode_url {
	my ($s) = @_;

	$s =~ s/\%([a-fA-F0-9][a-fA-F0-9])/pack('C', hex($1))/sge;
	return $s;
}

sub checked {
	my ($expr) = @_;

	return $expr ? ' checked="checked"' : '';
}

sub selected {
	my ($expr) = @_;

	return $expr ? ' selected="selected"' : '';
}

sub disabled {
	my ($expr) = @_;

	return $expr ? ' disabled="disabled"' : '';
}

sub nl2br {
	my ($text) = @_;

	$text =~ s/(\r?\n)/<br \/>$1/g;
	return $text;
}


sub text2html {
	my ($text) = @_;

	$text = escape_xml($text);
	$text =~ s/(\r?\n)/<br \/>$1/g;
	return $text;
}


sub tagattr {   ## [experimental]
	my ($name, $expr, $value) = @_;

	return '' unless $expr;
	$value = $expr unless defined($value);
	return " $name=\"$value\"";
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::HTML - HTML methods for Tenjin.

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
