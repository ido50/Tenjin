package Tenjin::Engine;

use strict;

sub new {
	my ($class, $options) = @_;

	my $this = {};
	foreach (qw[prefix postfix layout path cache preprocess templateclass]) {
		$this->{$_} = delete($options->{$_});
	}
	$this->{cache} = 1 unless defined($this->{cache});
	$this->{init_opts_for_template} = $options;
	$this->{templates} = {};
	$this->{prefix} = '' if (! $this->{prefix});
	$this->{postfix} = '' if (! $this->{postfix});

	return bless($this, $class);
}

sub to_filename {
	my ($this, $template_name) = @_;

	if (substr($template_name, 0, 1) eq ':') {
		return $this->{prefix} . substr($template_name, 1) . $this->{postfix};
	}

	return $template_name;
}

sub find_template_file {
	my ($this, $filename) = @_;

	my $path = $this->{path};
	if ($path) {
		my $sep = $^O eq 'MSWin32' ? '\\\\' : '/';
		foreach my $dirname (@$path) {
			my $filepath = $dirname . $sep . $filename;
			return $filepath if (-f $filepath);
		}
	} else {
		return $filename if (-f $filename);
	}
	my $s = $path ? ("['" . join("','", @$path) . "']") : '[]';
	die "Tenjin::Engine: $filename not found (path=$s).";
}

sub register_template {
	my ($this, $template_name, $template) = @_;

	$this->{templates}->{$template_name} = $template;
}

sub get_template {
	my ($this, $template_name, $_context) = @_;

	my $template = $this->{templates}->{$template_name};
	if (! $template || $template->{timestamp} && $template->{filename} && $template->{timestamp} < _mtime($template->{filename})) {
		my $filename = $this->to_filename($template_name);
		my $filepath = $this->find_template_file($filename);
		$template = $this->create_template($filepath, $_context);  # $_context is passed only for preprocessor
		$this->register_template($template_name, $template);
	}

	return $template;
}

sub read_template_file {
	my ($this, $template, $filename, $_context) = @_;

	my $input;
	if ($this->{preprocess}) {
		if (! defined($_context) || ! $_context->{_engine}) {
			$_context = {};
			$this->hook_context($_context);
		}
		$input = (new Tenjin::Template::Preprocessor($filename))->render($_context);
	} else {
		$input = Tenjin::Util::read_file($filename, 1);
	}
	return $input;
}

sub store_cachefile {
	my ($this, $cachename, $template) = @_;

	my $cache = $template->{script};
	if (defined($template->{args})) {
		my $args = $template->{args};
		$cache = "\#\@ARGS " . join(',', @$args) . "\n" . $cache;
	}
	Tenjin::Util::write_file($cachename, $cache, 1);
}

sub load_cachefile {
	my ($this, $cachename, $template) = @_;

	my $cache = Tenjin::Util::read_file($cachename, 1);
	if ($cache =~ s/\A\#\@ARGS (.*)\r?\n//) {
		my $argstr = $1;
		$argstr =~ s/\A\s+|\s+\Z//g;
		my @args = split(',', $argstr);
		$template->{args} = \@args;
	}
	$template->{script} = $cache;
}

sub cachename {
	my ($this, $filename) = @_;

	return $filename . '.cache';
}

sub create_template {
	my ($this, $filename, $_context) = @_;

	my $cachename = $this->cachename($filename);

	my $template = Tenjin::Template->new(undef, $this->{init_opts_for_template});
	$template->{timestamp} = time();
	if (! $this->{cache}) {
		#print STDERR "*** debug: caching is off.\n";
		$template->convert($this->read_template_file($template, $filename, $_context), $filename);
	} elsif ( !(-f $cachename) || ((-f $filename) && _mtime($cachename) < _mtime($filename)) ) {
		#print STDERR "*** debug: $cachename: cache file is not found or old.\n";
		$template->convert($this->read_template_file($template, $filename, $_context), $filename);
		$this->store_cachefile($cachename, $template);
	} else {
		#print STDERR "*** debug: $cachename: cache file is found.\n";
		$template->{filename} = $filename;
		$this->load_cachefile($cachename, $template);
	}
	$template->compile();

	return $template;
}

sub _mtime {
	my ($filename) = @_;

	return (stat($filename))[9];
}

sub _render {
	my ($this, $template_name, $context, $layout) = @_;

	$context = {} unless defined($context);
	$layout = 1 unless defined($layout);
	$context->{_engine} = $this;
	my $output;
	while (1) {
		my $template = $this->get_template($template_name, $context); # pass $context only for preprocessing
		$output = $template->_render($context);
		return $template->{filename} if ($@); # return template filename when error happened
		$layout = $context->{_layout} if exists($context->{_layout});
		$layout = $this->{layout} if $layout == 1;
		last unless $layout;
		$template_name = $layout;
		$layout = undef;
		$context->{_content} = $output;
		delete($context->{_layout});
	}
	return $output;
}


sub render {
	my $this = shift;

	my $ret = $this->_render(@_);
	if ($@) {  # error happened
		my $template_filename = $ret;
		die "Tenjin::Engine: Failed rendering $template_filename\n", $@;
	}

	return $ret;
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin::Engine - Tenjin's engine.

=head1 SYNOPSIS

	used internally. See L<Tenjin> for usage details.

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
