package Tenjin;

use Tenjin::Context;
use Tenjin::Template;
use Tenjin::Preprocessor;

use strict;
use warnings;

our $VERSION = 0.06;
our $USE_STRICT = 0;
our $ENCODING = 'utf8';
our $BYPASS_TAINT   = 1; # unset if you like taint mode
our $TEMPLATE_CLASS = 'Tenjin::Template';
our $CONTEXT_CLASS  = 'Tenjin::Context';
our $PREPROCESSOR_CLASS = 'Tenjin::Preprocessor';
our $TIMESTAMP_INTERVAL = 10;

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

	my $engine = Tenjin->new(\%options);
	my $context = { title => 'Tenjin Example', items => [qw/AAA BBB CCC/] };
	my $filename = 'file.html';
	my $output = $engine->render($filename, $context);
	print $output;

=head1 VERSION

0.06

=head1 DESCRIPTION

Tenjin is a very fast and full-featured templating engine, implemented in several programming languages, among them Perl.

The Perl version of Tenjin supports embedded Perl code, nestable layout template,
inclusion of other templates inside a template, capturing parts of or the entire
template output, file and memory caching, template arguments and preprocessing.

The original version of Tenjin is developed by Makoto Kuwata. This CPAN
version is developed by Ido Perlmuter and differs from the original in a
few key aspects:

=over

=item * Code is entirely revised, packages are separated into modules, with
a smaller number of packages than the original version. In particular, the
Tenjin::Engine module no longer exists, and is now instead just the Tenjin
module (i.e. this one).

=item * Support for rendering templates from non-files sources (such as
a database) is added.

=item * Ability to set the encoding of your templates is added.

=item * HTML is encoded and decoded using the L<HTML::Entities> module,
instead of internally.

=item * The C<pltenjin> script is not provided, at least for now.

=back

To make it clear, this version of Tenjin might somehow divert from the
original Tenjin's roadmap. Although my aim is to be as compatible as
possible (and this version is always updated with features and changes
from the original), I cannot guarantee it. Please note that version 0.05
of this module is NOT backwards compatible with previous versions.

=head1 METHODS

=head2 new( \%options )

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
filesystem (this means the template's code will be cached, not the completed rendered
output).

=item * B<preprocess> - Enable template preprocessing (turned off by default). Only
use if you're actually using any preprocessed Perl code in your templates.

=item * B<layout> - Name of a layout template that can be optionally used. If set,
templates will be automatically inserted into the layout template,
in the location where you use C<[== $_content ==]>.

=item * B<strict> - Another way to make Tenjin use strict on embedded Perl code (turned
off by default).

=item * B<encoding> - Another way to set the encoding of your template files (set to utf8
by default).

=back

=cut

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

	return bless $self, $class;
}

=head2 render( $tmpl_name, [\%context, $use_layout] )

Renders a template whose name is identified by C<$tmpl_name>. Remember that a prefix
and a postfix might be added if they where set when creating the Tenjin instance.

C<$context> is a hash-ref containing the variables that will be available for usage inside
the templates. So, for example, if your C<\%context> is { message => 'Hi there }, then
you can use C<$message> inside your templates.

C<$use_layout> is a flag denoting whether or not to render this template into a layout
template (when doing so, the template will be rendered, then the rendered output will be
added to the context hash-ref as '_content', and finally the layout template will be rendered
with the revised context and returned. If C<$use_layout> is 1, than Tenjin will use the
layout template that was set when creating the Tenjin instance (via the 'layout' configuration
option). If you want to use a different layout template (or if you haven't defined a layout
template when creating the Tenjin instance), then you must add the layout template's name
to the context as '_layout'. You can also just pass the layout template's name as C<$use_layout>,
which has precendence over C<< $context->{_layout} >>. If C<$use_layout> is 0 or undefined,
then a layout template will not be used, even if C<< $context->{_layout} >> is defined.

Please note that by default file templates are cached on disk (with a '.cache') extension.
Tenjin automatically deprecates these cache files every 10 seconds. If you
find this value is too low, you can override the C<$Tenjin::TIMESTAMP_INTERVAL>
variable with your preferred value.

=cut

sub render {
	my ($self, $template_name, $context, $use_layout) = @_;

	$context ||= {};
	$context->{'_engine'} = $self;

	my $template = $self->get_template($template_name, $context); # pass $context only for preprocessing
	my $output = $template->_render($context);
	die("*** ERROR: $template->{filename}\n", $@) if $@;

	# should we render inside a layout template?
	if ($use_layout) {
		# was a layout template name passed, or should we use the layout defined
		# in when creating the engine instance?
		my $layout_tmpl = $use_layout =~ m/^1$/ ? $self->{layout} : $use_layout;
		$layout_tmpl ||= $context->{_layout};
		
		# make sure we have a layout template to render
		return $output unless $layout_tmpl;

		# add the output of the rendered template to the context as '_content'
		# and remove the reference to the layout from the context (if present)
		$context->{_content} = $output;
		delete $context->{_layout};
		
		# render the layout template
		$output = $self->get_template($layout_tmpl, $context)->_render($context);
		die("*** ERROR: $layout_tmpl\n", $@) if $@;
	}

	return $output;
}

=head2 register_template( $template_name, $template )

Receives the name of a template and its L<Tenjin::Template> object
and stores it in memory for usage by the engine.

=cut

sub register_template {
	my ($self, $template_name, $template) = @_;

	$template->{timestamp} = time;
	$self->{templates}->{$template_name} = $template;
}

=head1 INTERNAL METHODS

=head2 get_template( $template_name, $context )

Receives the name of a template and the context object and tries to find
that template in the engine's memory. If it's not there, it will try to find
it in the file system (the cache file might be loaded, if present). Returns
the templates L<Tenjin::Template> object.

=cut

sub get_template {
	my ($self, $template_name, $context) = @_;

	## get cached template
	my $template = $self->{templates}->{$template_name};

	## check whether template file is updated or not
	undef $template if ($template && $template->{filename} && $template->{timestamp} + $TIMESTAMP_INTERVAL <= time);

	## load and register template
	unless ($template) {
		my $filename = $self->to_filename($template_name);
		my $filepath = $self->find_template_file($filename);
		$template = $self->create_template($filepath, $context);  # $context is passed only for preprocessor
		$self->register_template($template_name, $template);
	}

	return $template;
}

=head2 to_filename( $template_name )

Receives a template name and returns the proper file name to be searched
in the file system, which will only be different than C<$template_name>
if it begins with ':', in which case the prefix and postfix configuration
options will be appended and prepended to the template name (minus the ':'),
respectively.

=cut

sub to_filename {
	my ($self, $template_name) = @_;

	if (substr($template_name, 0, 1) eq ':') {
		return $self->{prefix} . substr($template_name, 1) . $self->{postfix};
	}

	return $template_name;
}

=head2 find_template_file( $filename )

Receives a template filename and searches for it in the path defined in
the configuration options (or, if a path was not set, in the current
working directory). Returns the absolute path to the file.

=cut

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

=head2 read_template_file( $template, $filename, $context )

Receives a template object and its absolute file path and reads that file.
If preprocessing is on, preprocessing will take place using the provided
context object.

=cut

sub read_template_file {
	my ($self, $template, $filename, $context) = @_;

	if ($self->{preprocess}) {
		if (! defined($context) || ! $context->{_engine}) {
			$context ||= {};
			$context->{'_engine'} = $self;
		}
		my $pp = $Tenjin::PREPROCESSOR_CLASS->new();
		$pp->convert($template->_read_file($filename));
		return $pp->render($context);
	}

	return $template->_read_file($filename, 1);
}

=head2 cachename( $filename )

Receives a template filename and returns its standard cache filename (which
will simply be C<$filename> with '.cache' appended to it.

=cut

sub cachename {
	my ($self, $filename) = @_;

	return $filename . '.cache';
}

=head2 store_cachefile( $cachename, $template )

Receives the name of a template cache file and the corrasponding template
object, and creates the cache file on disk.

=cut

sub store_cachefile {
	my ($self, $cachename, $template) = @_;

	my $cache = $template->{script};
	if (defined $template->{args}) {
		my $args = $template->{args};
		$cache = "\#\@ARGS " . join(',', @$args) . "\n" . $cache;
	}
	$template->_write_file($cachename, $cache, 1);
}

=head2 load_cachefile( $cachename, $template )

Receives the name of a template cache file and the corrasponding template
object, reads the cache file and stores it in the template object (as 'script').

=cut

sub load_cachefile {
	my ($self, $cachename, $template) = @_;

	my $cache = $template->_read_file($cachename, 1);
	if ($cache =~ s/\A\#\@ARGS (.*)\r?\n//) {
		my $argstr = $1;
		$argstr =~ s/\A\s+|\s+\Z//g;
		my @args = split(',', $argstr);
		$template->{args} = \@args;
	}
	$template->{script} = $cache;
}

=head2 create_template( $filename, $context )

Receives an absolute path to a template file and the context object, reads
the file, processes it (which may involve loading the template's cache file
or creating the template's cache file), compiles it and returns the template
object.

=cut

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

__PACKAGE__;

__END__

=head1 SEE ALSO

The original Tenjin website is located at L<http://www.kuwata-lab.com/tenjin/>. In there check out
L<http://www.kuwata-lab.com/tenjin/pltenjin-users-guide.html> for detailed usage guide,
L<http://www.kuwata-lab.com/tenjin/pltenjin-examples.html> for examples, and
L<http://www.kuwata-lab.com/tenjin/pltenjin-faq.html> for frequently asked questions.

Note that the Perl version of Tenjin is refered to as plTenjin on the Tenjin website,
and that, as oppose to this module, the website suggests using a .plhtml extension
for the templates instead of .html (this is entirely your choice).

L<Tenjin::Template>, L<Catalyst::View::Tenjin>, L<Dancer::Template::Tenjin>.

=head1 CHANGES

Version 0.05 of this module broke backwards compatibility with previous versions.
In particular, the Tenjin::Engine module does not exist any more and is
instead integrated into this one. Templates are also rendered entirely
different (as per changes in the original tenjin) which provides much
faster rendering.

Upon upgrading to versions 0.05 and above, you MUST perform the following changes
for your applications (or, if you're using Catalyst, you must also upgrade
L<Catalyst::View::Tenjin>):

=over

=item * C<use Tenjin> as your normally would, but to get an instance
of Tenjin you must call C<< Tenjin->new() >> instead of the old method
of calling C<< Tenjin::Engine->new() >>.

=item * Remove all your templates cache files (they are the '.cache' files
in your template directories), they are not compatible with the new
templates structure and WILL cause your application to fail if present.

=back

Version 0.06 (this version) restored the layout template feature which was
accidentaly missing in version 0.05, and the ability to call the utility
methods of L<Tenjin::Util> natively inside templates. You will want to
remove your templates' .cache files when upgrading to 0.6 too.

=head1 TODO

=over

=item * Expand pod documentation and properly document the code, which is
hard to understand as it is.

=item * Create tests, adapted from the tests provided by the original Tenjin.

=back

=head1 AUTHOR

Tenjin is developed by Makoto Kuwata at L<http://www.kuwata-lab.com/tenjin/>.
The CPAN version was tidied and CPANized from the original 0.0.2 source (with later updates from Makoto Kuwata's tenjin github repository) by Ido Perlmuter E<lt>ido@ido50.netE<gt>.

=head1 BUGS

Please report any bugs or feature requests to C<bug-tenjin at rt.cpan.org>,
or through the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Tenjin>.  I will be notified, and then you'll automatically be notified of progress
on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Tenjin

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Tenjin>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Tenjin>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Tenjin>

=item * Search CPAN

L<http://search.cpan.org/dist/Tenjin/>

=back

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

See http://dev.perl.org/licenses/ for more information.

=cut
