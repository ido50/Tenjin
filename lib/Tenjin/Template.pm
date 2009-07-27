package Tenjin::Template;

use strict;

our $MACRO_HANDLER_TABLE = {
	'include' => sub { my ($arg) = @_;
		"push(\@_buf, \$_context->{_engine}->render($arg, \$_context, 0));";
	},
	'start_capture' => sub { my ($arg) = @_;
		"my \@_buf_bkup=\@_buf; \@_buf=(); my \$_capture_varname=$arg;";
	},
	'stop_capture' => sub { my ($arg) = @_;
		"\$_context->{\$_capture_varname}=join('',\@_buf); \@_buf=\@_buf_bkup;";
	},
	'start_placeholder' => sub { my ($arg) = @_;
		"if (\$_context->{$arg}) { push(\@_buf,\$_context->{$arg}); } else {";
	},
	'stop_placeholder' => sub { my ($arg) = @_;
		"}";
	},
	'echo' => sub { my ($arg) = @_;
		"push(\@_buf, $arg);";
	},
};

sub new {
	my ($class, $filename, $opts) = @_;

	my $escapefunc = defined($opts) && exists($opts->{escapefunc}) ? $opts->{escapefunc} : 'escape';

	my $this = bless({ 'filename' => $filename, 'script' => undef, 'escapefunc' => $escapefunc, 'timestamp' => undef, 'args' => undef }, $class);
	$this->convert_file($filename) if $filename;

	return $this;
}

sub _render {
	my ($this, $context) = (@_);

	$context = {} unless $context;

	if ($this->{func}) {
		return $this->{func}->($context);
	} else {
		if (ref($context) eq 'HASH') {
			$context = Tenjin::Context->new($context);
		}
		my $script;
		$script = $context->_build_decl() . $this->{script} unless ($this->{args});
		return $context->evaluate($script);
	}
}

sub render {
	my ($this, $context) = @_;

	my $output = $this->_render($context);
	if ($@) {  # error happened
		my $template_filename = $this->{filename};
		die "Tenjin::Template: Error rendering " . $this->{filename} . "\n", $@;
	}
	return $output;
}

sub convert_file {
	my ($this, $filename) = @_;

	my $input = Tenjin::Util::read_file($filename, 1);
	my $script = $this->convert($input);
	$this->{filename} = $filename;

	return $script;
}

sub convert {
	my ($this, $input, $filename) = @_;

	$this->{filename} = $filename;
	my @buf = ('my @_buf = (); ', );
	$this->parse_stmt(\@buf, $input);
	push(@buf, "join('', \@_buf);\n");
	$this->{script} = join('', @buf);

	return $this->{script};
}

sub compile_stmt_pattern {
	my ($pi) = @_;

	my $pat = '((^[ \t]*)?<\?'.$pi.'( |\t|\r?\n)(.*?) ?\?>([ \t]*\r?\n)?)';
	return qr/$pat/sm;
}

sub stmt_pattern {
	return compile_stmt_pattern('pl');
}

sub parse_stmt {
	my ($this, $bufref, $input) = @_;

	my $pos = 0;
	my $pat = $this->stmt_pattern();
	while ($input =~ /$pat/g) {
		my ($pi, $lspace, $mspace, $stmt, $rspace) = ($1, $2, $3, $4, $5);
		my $start = $-[0];
		my $text = substr($input, $pos, $start - $pos);
		$pos = $start + length($pi);
		if ($text) {
			$this->parse_expr($bufref, $text);
		}
		$mspace = '' if $mspace eq ' ';
		$stmt = $this->hook_stmt($stmt);
		$this->add_stmt($bufref, $lspace . $mspace . $stmt . $rspace);
	}
	my $rest = $pos == 0 ? $input : substr($input, $pos);
	$this->parse_expr($bufref, $rest) if $rest;
}

sub hook_stmt {
	my ($this, $stmt) = @_;

	## macro expantion
	if ($stmt =~ /\A(\s*)(\w+)\((.*?)\);?(\s*)\Z/) {
		my ($lspace, $funcname, $arg, $rspace) = ($1, $2, $3, $4);
		my $s = $this->expand_macro($funcname, $arg);
		return $lspace . $s . $rspace if defined($s);
	}

	## template arguments
	unless ($this->{args}) {
		if ($stmt =~ m/\A(\s*)\#\@ARGS\s+(.*)(\s*)\Z/) {
			my ($lspace, $argstr, $rspace) = ($1, $2, $3);
			my @args = ();
			my @declares = ();
			foreach my $arg (split(/,/, $argstr)) {
				$arg =~ s/(^\s+|\s+$)//g;
				next unless $arg;
				$arg =~ m/\A[a-zA-Z_]\w*\Z/ or die("Tenjin::Template: invalid template argument '$arg'.");
				push(@args, $arg);
				push(@declares, "my \$$arg = \$_context->{$arg}; ");
			}
			$this->{args} = \@args;
			return $lspace . join('', @declares) . $rspace;
		}
	}

	return $stmt;
}

sub expand_macro {
	my ($this, $funcname, $arg) = @_;

	my $handler = $MACRO_HANDLER_TABLE->{$funcname};
	return $handler ? $handler->($arg) : undef;
}

sub expr_pattern {
	return qr/\[=(=?)(.*?)(=?)=\]/s;
}

## ex. get_expr_and_escapeflag('=', '$item->{name}', '')  => 1, '$item->{name}', 0
sub get_expr_and_escapeflag {
	my ($this, $not_escape, $expr, $delete_newline) = @_;

	return $expr, $not_escape eq '', $delete_newline eq '=';
}

sub parse_expr {
	my ($this, $bufref, $input) = @_;

	my $pos = 0;
	$this->start_text_part($bufref);
	my $pat = $this->expr_pattern();
	while ($input =~ /$pat/g) {
		my $start = $-[0];
		my $text = substr($input, $pos, $start - $pos);
		my ($expr, $flag_escape, $delete_newline) = $this->get_expr_and_escapeflag($1, $2, $3);
		$pos = $start + length($&);
		$this->add_text($bufref, $text) if ($text);
		$this->add_expr($bufref, $expr, $flag_escape) if $expr;
		if ($delete_newline) {
			my $end = $+[0];
			if (substr($input, $end+1, 1) == "\n") {
				push(@$bufref, "\n");
				$pos += 1;
			}
		}
	}
	my $rest = $pos == 0 ? $input : substr($input, $pos);
	$this->add_text($bufref, $rest);
	$this->stop_text_part($bufref);
}

sub start_text_part {
	my ($this, $bufref) = @_;

	push(@$bufref, "push(\@_buf, ");
}


sub stop_text_part {
	my ($this, $bufref) = @_;

	push(@$bufref, "); ");
}


sub add_text {
	my ($this, $bufref, $text) = @_;

	return unless $text;
	$text =~ s/[`\\]/\\$&/g;
	push(@$bufref, "q`$text`, ");
}


sub add_stmt {
	my ($this, $bufref, $stmt) = @_;

	push(@$bufref, $stmt);
}

sub add_expr {
	my ($this, $bufref, $expr, $flag_escape) = @_;

	if ($flag_escape) {
		my $funcname = $this->{escapefunc};
		push(@$bufref, "$funcname($expr), ");
	} else {
		push(@$bufref, "$expr, ");
	}
}


sub defun {   ## (experimental)
	my ($this, $funcname, @args) = @_;

	unless ($funcname) {
		$_ = $this->{filename};
		s/\.\w+$//  if ($_);
		s/[^\w]/_/g if ($_);
		$funcname = "render_" . $_;
	}

	my @buf = ();
	push(@buf, "sub $funcname {");
	push(@buf, " my (\$_context) = \@_; ");
	foreach (@args) {
		push(@buf, "my \$$_ = \$_context->{'$_'}; ");
	}
	push(@buf, $this->{script});
	push(@buf, "}\n");

	return join('', @buf);
}

## compile $this->{script} into closure.
sub compile {
	my $this = shift;

	if ($this->{args}) {
		my $func = Tenjin::Context->to_func($this->{script});
		die("Tenjin::Template: Error compiling " . $this->{filename} . "\n", $@) if $@;
		return $this->{func} = $func;
	}
	return;
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
