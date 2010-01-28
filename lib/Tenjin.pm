package Tenjin;

use Tenjin::Context;
use Tenjin::Template;
use Tenjin::Preprocessor;
use Tenjin::Util;

use strict;
use warnings;

our $VERSION = 0.05;
our $USE_STRICT = 0;
our $ENCODING = 'utf8';
our $BYPASS_TAINT   = 1; # unset if you like taint mode
our $TEMPLATE_CLASS = 'Tenjin::Template';
our $CONTEXT_CLASS  = 'Tenjin::Context';
our $PREPROCESSOR_CLASS = 'Tenjin::Preprocessor';
our $TIMESTAMP_INTERVAL = 3600;

sub new {
	my ($class, $options) = @_;

	my $self = {};
	foreach (qw[prefix postfix layout path cache preprocess templateclass strict encoding]) {
		$self->{$_} = delete $options->{$_};
	}
	$self->{cache} = 1 unless defined $self->{cache};
	$self->{init_opts_for_template} = $options;
	$self->{templates} = {};
	$self->{prefix} = '' unless $self->{prefix};
	$self->{postfix} = '' unless $self->{postfix};

	if ($self->{encoding}) {
		$Tenjin::ENCODING = $self->{encoding};
	}
	if (defined $self->{strict}) {
		$Tenjin::USE_STRICT = $self->{strict};
	}

	$self->{utils} = Tenjin::Util->new();

	return bless $self, $class;
}

sub to_filename {
	my ($self, $template_name) = @_;

	if (substr($template_name, 0, 1) eq ':') {
		return $self->{prefix} . substr($template_name, 1) . $self->{postfix};
	}

	return $template_name;
}

sub find_template_file {
	my ($self, $filename) = @_;

	my $path = $self->{path};
	if ($path) {
		my $sep = $^O eq 'MSWin32' ? '\\\\' : '/';
		foreach my $dirname (@$path) {
			my $filepath = $dirname . $sep . $filename;
			return $filepath if -f $filepath;
		}
	} else {
		return $filename if -f $filename;
	}
	my $s = $path ? ("['" . join("','", @$path) . "']") : '[]';
	die "Tenjin::Engine: \"$filename not found (path=$s)\".";
}

sub register_template {
	my ($self, $template_name, $template) = @_;

	$template->{timestamp} = time;
	$self->{templates}->{$template_name} = $template;
}

sub get_template {
	my ($self, $template_name, $context) = @_;

	## get cached template
	my $template = $self->{templates}->{$template_name};

	## check whether template file is updated or not
	undef $template if ($template && $template->{timestamp} + $TIMESTAMP_INTERVAL <= time);

	## load and register template
	unless ($template) {
		my $filename = $self->to_filename($template_name);
		my $filepath = $self->find_template_file($filename);
		$template = $self->create_template($filepath, $context);  # $context is passed only for preprocessor
		$self->register_template($template_name, $template);
	}

	return $template;
}

sub read_template_file {
	my ($self, $template, $filename, $context) = @_;

	if ($self->{preprocess}) {
		if (! defined($context) || ! $context->{_engine}) {
			$context ||= {};
			$context->{'_engine'} = $self;
		}
		my $pp = $Tenjin::PREPROCESSOR_CLASS->new();
		$pp->convert($self->_read_file($filename));
		return $pp->render($context);
	}

	return $self->{utils}->read_file($filename, 1);
}

sub store_cachefile {
	my ($self, $cachename, $template) = @_;

	my $cache = $template->{script};
	if (defined $template->{args}) {
		my $args = $template->{args};
		$cache = "\#\@ARGS " . join(',', @$args) . "\n" . $cache;
	}
	$self->{utils}->write_file($cachename, $cache, 1);
}

sub load_cachefile {
	my ($self, $cachename, $template) = @_;

	my $cache = $self->{utils}->read_file($cachename, 1);
	if ($cache =~ s/\A\#\@ARGS (.*)\r?\n//) {
		my $argstr = $1;
		$argstr =~ s/\A\s+|\s+\Z//g;
		my @args = split(',', $argstr);
		$template->{args} = \@args;
	}
	$template->{script} = $cache;
}

sub cachename {
	my ($self, $filename) = @_;

	return $filename . '.cache';
}

sub create_template {
	my ($self, $filename, $context) = @_;

	my $cachename = $self->cachename($filename);

	my $class = $self->{templateclass} || $Tenjin::TEMPLATE_CLASS;
	my $template = $class->new(undef, $self->{init_opts_for_template});

	if (! $self->{cache}) {
		$template->convert($self->read_template_file($template, $filename, $context), $filename);
	} elsif (! -f $cachename || (stat $cachename)[9] < (stat $filename)[9]) {
		$template->convert($self->read_template_file($template, $filename, $context), $filename);
		$self->store_cachefile($cachename, $template);
	} else {
		$template->{filename} = $filename;
		$self->load_cachefile($cachename, $template);
	}
	$template->compile();

	return $template;
}

sub render {
	my ($self, $template_name, $context) = @_;

	$context ||= {};
	$context->{'_engine'} = $self;
	
	use Data::Dumper;
	print STDERR "\n==================\n", Dumper($context), "\n==================\n";

	my $template = $self->get_template($template_name, $context); # pass $context only for preprocessing
	my $output = $template->_render($context);
	die("*** ERROR: $template->{filename}\n", $@) if $@;

	return $output;
}

__PACKAGE__;

__END__

=pod

=head1 NAME

Tenjin - Fast templating engine with support for embedded Perl.

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

=head1 DESCRIPTION

Tenjin is a very fast and full-featured templating engine, implemented in several programming languages.
It supports embedded Perl, nestable layout template, inclusion of other templates inside a template,
capturing parts of or the entire template output, file and memory caching, template arguments and preprocessing.

Tenjin also comes with a command line application, C<pltenjin>, for rendering templates. For example,
C<pltenjin example.html> will render the template stored in the example.html file. You can also convert
a template to Perl code by using C<pltenjin -s example.html>. This is the code used internally
by Tenjin when rendering templates. There are more options, checkout SEE ALSO for links to the usage guides.

=head1 METHODS

=head2 new \%options

This creates a new instant of Tenjin. C<\%options> is a hash-ref
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
and a postfix might be added if they where set when creating the Tenjin instance.

C<$context> is a hash-ref containing the variables that will be available for usage inside
the templates. So, for example, if your C<\%context> is { message => 'Hi there }, then
you can use C<$message> inside your templates.

C<$layout> is a flag denoting whether or not to render this template into the layout template
there was set when creating the Tenjin instance.

=head1 SEE ALSO

The original Tenjin website is located at L<http://www.kuwata-lab.com/tenjin/>. In there check out
L<http://www.kuwata-lab.com/tenjin/pltenjin-users-guide.html> for detailed usage guide,
L<http://www.kuwata-lab.com/tenjin/pltenjin-examples.html> for examples, and
L<http://www.kuwata-lab.com/tenjin/pltenjin-faq.html> for frequently asked questions.

Note that the Perl version of Tenjin is refered to as plTenjin on the Tenjin website,
and that, as oppose to this module, the website suggests using a .plhtml extension
for the templates instead of .html (this is entirely your choice).

L<Tenjin::Template>, L<Catalyst::View::Tenjin>.

=head1 TODO

=over

=item * Check if all the sub-modules (like L<Tenjin::Context>, L<Tenjin::HTML>, etc.) are really necessary.

=item * In particular, check if L<Tenjin::HTML> can be replaced with some existing CPAN module (HTML::Tiny was suggested).

=item * Add the documentation files linked in SEE ALSO to the module distribution, like in the original Tenjin.

=item * Expand the description of this module.

=item * Create tests, adapted from the tests provided by the original Tenjin.

=back

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>. Version 0.03 was tidied and CPANized from the original 0.0.2 source (with later updates from Makoto Kuwata's tenjin github repository) by Ido Perlmuter E<lt>ido@ido50.netE<gt>.

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
