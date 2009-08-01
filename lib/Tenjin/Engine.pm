package Tenjin::Engine;

use strict;

sub new {
	my ($class, $options) = @_;

	my $this = {};
	foreach (qw[prefix postfix layout path cache preprocess templateclass strict encoding]) {
		$this->{$_} = delete $options->{$_};
	}
	$this->{cache} = 1 unless defined $this->{cache};
	$this->{init_opts_for_template} = $options;
	$this->{templates} = {};
	$this->{prefix} = '' unless $this->{prefix};
	$this->{postfix} = '' unless $this->{postfix};

	if ($this->{encoding}) {
		$Tenjin::ENCODING = $this->{encoding};
	}
	if (defined $this->{strict}) {
		$Tenjin::USE_STRICT = $this->{strict};
	}

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

	use Tenjin;

	$Tenjin::USE_STRICT = 1;	# use strict in the embedded Perl inside
					# your templates. Recommended, but not used
					# by default.

	$Tenjin::ENCODING = "utf8";	# set the encoding of your template files
					# to utf8. This is the default encoding used
					# so there's no need to do this if your
					# templates really are utf8.

	my $engine = new Tenjin::Engine(\%options);
	my $context = { title => 'Tenjin Example', items => [qw/AAA BBB CCC/] };
	my $filename = 'file.html';
	my $output = $engine->render($filename, $context);
	print $output;

=head1 METHODS

=head2 new \%options

This creates a new instant of Tenjin::Engine. C<\%options> is a hash-ref
containing Tenjin's configuration options:

=over

=item * B<path> - Array-ref of filesystem paths where templates will be searched

=item * B<prefix> - A string that will be automatically prepended to template names
		 when searching for them in the path. Empty by default.

=item * B<postfix> - The default extension to be automtically appended to template names
		  when searching for them in the path. Don't forget to include the
		  dot, such as '.html'. Empty by default.

=item * B<cache> - If set to 1 (the default), compiled templates will be cached on the
		filesystem.

=item * B<preprocess> - Enable template preprocessing (turned off by default). Only
		     use if you're actually using any preprocessed Perl code in
		     your templates.

=item * B<layout> - Name of a layout template that can be optionally used. If set,
		 templates will be automatically inserted into the layout template,
		 in the location where you use C<[== $_content ==]>.

=item * B<strict> - Another way to make Tenjin use strict on embedded Perl code (turned
		 off by default).

=item * B<encoding> - Another way to set the encoding of your template files (set to utf8
		   by default).

=back

=head2 render $tmpl_name, [\%context, $layout]

Renders a template whose name is identified by C<$tmpl_name>. Remember that a prefix
and a postfix might be added if they where set when creating the Tenjin::Engine instant.

C<$context> is a hash-ref containing the variables that will be available for usage inside
the templates. So, for example, if your C<\%context> is { message => 'Hi there }, then
you can use C<$message> inside your templates.

C<$layout> is a flag denoting whether or not to render this template into the layout template
there was set when creating the Tenjin::Engine instant.

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
