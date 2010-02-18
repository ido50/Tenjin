package Tenjin::Template;

use strict;
use warnings;
use Tenjin::Util;

our $MACRO_HANDLER_TABLE = {
	'include' => sub { my $arg = shift;
		" \$_buf .= \$context->{'_engine'}->render($arg, \$context, 0);";
	},
	'start_capture' => sub { my $arg = shift;
		" my \$_buf_bkup=\$_buf; \$_buf=''; my \$_capture_varname=$arg;";
	},
	'stop_capture' => sub { my $arg = shift;
		" \$context->{\$_capture_varname}=\$_buf; \$_buf=\$_buf_bkup;";
	},
	'start_placeholder' => sub { my $arg = shift;
		" if (\$context->{$arg}) { \$_buf .= \$context->{$arg}; } else {";
	},
	'stop_placeholder' => sub { my $arg = shift;
		" }";
	},
	'echo' => sub { my $arg = shift;
		" \$_buf .= $arg;";
	},
};

sub new {
	my ($class, $filename, $opts) = @_;

	my $escapefunc = defined($opts) && exists($opts->{escapefunc}) ? $opts->{escapefunc} : undef;
	my $rawclass   = defined($opts) && exists($opts->{rawclass}) ? $opts->{rawclass} : undef;

	my $self = bless {
		'filename'   => $filename,
		'script'     => undef,
		'escapefunc' => $escapefunc,
		'rawclass'   => $rawclass,
		'timestamp'  => undef,
		'args'       => undef,
	}, $class;

	$self->{utils} = Tenjin::Util->new();
	
	$self->convert_file($filename) if $filename;

	return $self;
}

sub _render {
	my ($self, $context) = @_;

	$context ||= {};

	if ($self->{func}) {
		return $self->{func}->($context);
	} else {
		if (ref($context) eq 'HASH') {
			$context = $Tenjin::CONTEXT_CLASS->new($context);
		}
		my $script = $self->{script};
		$script = $context->_build_decl() . $script unless $self->{args};
		return $context->evaluate($script, $self->{filename});
	}
}

sub render {
	my $self = shift;

	my $output = $self->_render(@_);
	if ($@) {  # error happened
		my $template_filename = $self->{filename};
		die "Tenjin::Template: \"Error rendering " . $self->{filename} . "\"\n", $@;
	}
	return $output;
}

sub convert_file {
	my ($self, $filename) = @_;

	return $self->convert($self->{utils}->read_file($filename, 1), $filename);
}

sub convert {
	my ($self, $input, $filename) = @_;

	$self->{filename} = $filename;
	my @buf = ('my $_buf = ""; my $_V; ', );
	$self->parse_stmt(\@buf, $input);

	return $self->{script} = $buf[0] . " \$_buf;\n";
}

sub compile_stmt_pattern {
	my $pi = shift;

	my $pat = '((^[ \t]*)?<\?'.$pi.'( |\t|\r?\n)(.*?) ?\?>([ \t]*\r?\n)?)';
	return qr/$pat/sm;
}

sub stmt_pattern {
	return compile_stmt_pattern('pl');
}

sub parse_stmt {
	my ($self, $bufref, $input) = @_;

	my $pos = 0;
	my $pat = $self->stmt_pattern();
	while ($input =~ /$pat/g) {
		my ($pi, $lspace, $mspace, $stmt, $rspace) = ($1, $2, $3, $4, $5);
		my $start = $-[0];
		my $text = substr($input, $pos, $start - $pos);
		$pos = $start + length($pi);
		$self->parse_expr($bufref, $text) if $text;
		$mspace = '' if $mspace eq ' ';
		$stmt = $self->hook_stmt($stmt);
		$self->add_stmt($bufref, $lspace . $mspace . $stmt . $rspace);
	}
	my $rest = $pos == 0 ? $input : substr($input, $pos);
	$self->parse_expr($bufref, $rest) if $rest;
}

sub hook_stmt {
	my ($self, $stmt) = @_;

	## macro expantion
	if ($stmt =~ /\A(\s*)(\w+)\((.*?)\);?(\s*)\Z/) {
		my ($lspace, $funcname, $arg, $rspace) = ($1, $2, $3, $4);
		my $s = $self->expand_macro($funcname, $arg);
		return $lspace . $s . $rspace if defined($s);
	}

	## template arguments
	unless ($self->{args}) {
		if ($stmt =~ m/\A(\s*)\#\@ARGS\s+(.*)(\s*)\Z/) {
			my ($lspace, $argstr, $rspace) = ($1, $2, $3);
			my @args = ();
			my @declares = ();
			foreach my $arg (split(/,/, $argstr)) {
				$arg =~ s/(^\s+|\s+$)//g;
				next unless $arg;
				$arg =~ m/\A([\$\@\%])?([a-zA-Z_]\w*)\Z/ or die("Tenjin::Template: \"$arg: invalid template argument.\"");
				die "Tenjin::Template: \"$arg: only '\$var' is available for template argument.\"" unless (!$1 || $1 eq '$');
				my $name = $2;
				push(@args, $name);
				push(@declares, "my \$$name = \$context->{$name}; ");
			}
			$self->{args} = \@args;
			return $lspace . join('', @declares) . $rspace;
		}
	}

	return $stmt;
}

sub expand_macro {
	my ($self, $funcname, $arg) = @_;

	my $handler = $MACRO_HANDLER_TABLE->{$funcname};
	return $handler ? $handler->($arg) : undef;
}

sub expr_pattern {
	return qr/\[=(=?)(.*?)(=?)=\]/s;
}

## ex. get_expr_and_escapeflag('=', '$item->{name}', '')  => 1, '$item->{name}', 0
sub get_expr_and_escapeflag {
	my ($self, $not_escape, $expr, $delete_newline) = @_;

	return $expr, $not_escape eq '', $delete_newline eq '=';
}

sub parse_expr {
	my ($self, $bufref, $input) = @_;

	my $pos = 0;
	$self->start_text_part($bufref);
	my $pat = $self->expr_pattern();
	while ($input =~ /$pat/g) {
		my $start = $-[0];
		my $text = substr($input, $pos, $start - $pos);
		my ($expr, $flag_escape, $delete_newline) = $self->get_expr_and_escapeflag($1, $2, $3);
		$pos = $start + length($&);
		$self->add_text($bufref, $text) if $text;
		$self->add_expr($bufref, $expr, $flag_escape) if $expr;
		if ($delete_newline) {
			my $end = $+[0];
			if (substr($input, $end + 1, 1) eq "\n") {
				$bufref->[0] .= "\n";
				$pos++;
			}
		}
	}
	my $rest = $pos == 0 ? $input : substr($input, $pos);
	$self->add_text($bufref, $rest);
	$self->stop_text_part($bufref);
}

sub start_text_part {
	my ($self, $bufref) = @_;

	$bufref->[0] .= ' $_buf .= ';
}

sub stop_text_part {
	my ($self, $bufref) = @_;

	$bufref->[0] .= '; ';
}

sub add_text {
	my ($self, $bufref, $text) = @_;

	return undef unless $text;
	$text =~ s/[`\\]/\\$&/g;
	my $is_start = $bufref->[0] =~ / \$_buf \.= \Z/;
	$bufref->[0] .= $is_start ? "q`$text`" : " . q`$text`";
}

sub add_stmt {
	my ($self, $bufref, $stmt) = @_;

	$bufref->[0] .= $stmt;
}

sub add_expr {
	my ($self, $bufref, $expr, $flag_escape) = @_;

	my $dot = $bufref->[0] =~ / \$_buf \.= \Z/ ? '' : ' . ';
	$bufref->[0] .= $dot . ($flag_escape ? $self->escaped_expr($expr) : "($expr)");
}

sub defun {   ## (experimental)
	my ($self, $funcname, @args) = @_;

	unless ($funcname) {
		my $funcname = $self->{filename};
		if ($funcname) {
			$funcname =~ s/\.\w+$//;
			$funcname =~ s/[^\w]/_/g;
		}
		$funcname = 'render_' . $funcname;
	}

	my $str = "sub $funcname { my (\$context) = \@_; ";
	foreach (@args) {
		$str .= "my \$$_ = \$context->{'$_'}; ";
	}
	$str .= $self->{script};
	$str .= "}\n";

	return $str;
}

## compile $self->{script} into closure.
sub compile {
	my $self = shift;

	if ($self->{args}) {
		my $func = $Tenjin::CONTEXT_CLASS->to_func($self->{script}, $self->{filename});
		die "Tenjin::Template: \"Error compiling " . $self->{filename} . "\"\n", $@ if $@;
		return $self->{func} = $func;
	}
	return undef;
}

sub escaped_expr {
	my ($self, $expr) = @_;

	return "$self->{escapefunc}($expr)" if $self->{escapefunc};

	return "(ref(\$_V = ($expr)) eq '$self->{rawclass}' ? \$_V->{str} : \$_engine->{utils}->escape_xml($expr)" if $self->{rawclass};

	return "\$_engine->{utils}->escape_xml($expr)";
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::Template

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
