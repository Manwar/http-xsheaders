package HTTP::XSHeaders;
use strict;
use warnings;
use XSLoader;

our $VERSION = '0.200000';

eval {
    require HTTP::Headers::Fast;

    # HTTP::Headers::Fast
    *HTTP::Headers::Fast::new                    = *HTTP::XSHeaders::new;
    *HTTP::Headers::Fast::DESTROY                = *HTTP::XSHeaders::DESTROY;
    *HTTP::Headers::Fast::clone                  = *HTTP::XSHeaders::clone;
    *HTTP::Headers::Fast::header                 = *HTTP::XSHeaders::header;
    *HTTP::Headers::Fast::clear                  = *HTTP::XSHeaders::clear;
    *HTTP::Headers::Fast::push_header            = *HTTP::XSHeaders::push_header;
    *HTTP::Headers::Fast::init_header            = *HTTP::XSHeaders::init_header;
    *HTTP::Headers::Fast::remove_header          = *HTTP::XSHeaders::remove_header;
    *HTTP::Headers::Fast::remove_content_headers = *HTTP::XSHeaders::remove_content_headers;
    *HTTP::Headers::Fast::as_string              = *HTTP::XSHeaders::as_string;
    *HTTP::Headers::Fast::as_string_without_sort = *HTTP::XSHeaders::as_string_without_sort;
    *HTTP::Headers::Fast::header_field_names     = *HTTP::XSHeaders::header_field_names;
    *HTTP::Headers::Fast::scan                   = *HTTP::XSHeaders::scan;

    # Implemented in Pure-Perl
    # (candidates to move to XS)
    *HTTP::Headers::Fast::_date_header          = *HTTP::XSHeaders::_date_header;
    *HTTP::Headers::Fast::content_type          = *HTTP::XSHeaders::content_type;
    *HTTP::Headers::Fast::content_type_charset  = *HTTP::XSHeaders::content_type_charset;
    *HTTP::Headers::Fast::referer               = *HTTP::XSHeaders::referer;
    *HTTP::Headers::Fast::referrer              = *HTTP::XSHeaders::referer;
    *HTTP::Headers::Fast::_basic_auth           = *HTTP::XSHeaders::_basic_auth;
};

eval {
    require HTTP::Headers;

    # HTTP::Headers
    *HTTP::Headers::new                    = *HTTP::XSHeaders::new;
    *HTTP::Headers::clone                  = *HTTP::XSHeaders::clone;
    *HTTP::Headers::header                 = *HTTP::XSHeaders::header;
    *HTTP::Headers::clear                  = *HTTP::XSHeaders::clear;
    *HTTP::Headers::push_header            = *HTTP::XSHeaders::push_header;
    *HTTP::Headers::init_header            = *HTTP::XSHeaders::init_header;
    *HTTP::Headers::remove_header          = *HTTP::XSHeaders::remove_header;
    *HTTP::Headers::remove_content_headers = *HTTP::XSHeaders::remove_content_headers;
    *HTTP::Headers::as_string              = *HTTP::XSHeaders::as_string;
    *HTTP::Headers::header_field_names     = *HTTP::XSHeaders::header_field_names;
    *HTTP::Headers::scan                   = *HTTP::XSHeaders::scan;

    # Implemented in Pure-Perl
    *HTTP::Headers::_date_header           = *HTTP::XSHeaders::_date_header;
    *HTTP::Headers::content_type           = *HTTP::XSHeaders::content_type;
    *HTTP::Headers::content_type_charset   = *HTTP::XSHeaders::content_type_charset;
    *HTTP::Headers::referer                = *HTTP::XSHeaders::referer;
    *HTTP::Headers::referrer               = *HTTP::XSHeaders::referer;
    *HTTP::Headers::_basic_auth            = *HTTP::XSHeaders::_basic_auth;
};

XSLoader::load( 'HTTP::XSHeaders', $VERSION );

{
    no warnings qw<redefine once>;
    for my $key (qw/content-length content-language content-encoding title user-agent server from warnings www-authenticate authorization proxy-authenticate proxy-authorization/) {
      (my $meth = $key) =~ s/-/_/g;
      no strict 'refs'; ## no critic
      *{ "HTTP::Headers::$meth" } = sub {
          (shift->header($key, @_))[0];
      };

      *{ "HTTP::Headers::Fast::$meth" } = sub {
          (shift->header($key, @_))[0];
      };
    }
}

use 5.00800;
use Carp ();

sub _date_header {
    require HTTP::Date;
    my ( $self, $header, $time ) = @_;
    my $old;
    if ( defined $time ) {
        ($old) = $self->header($header, HTTP::Date::time2str($time));
    } else {
        ($old) = $self->header($header);
    }
    $old =~ s/;.*// if defined($old);
    HTTP::Date::str2time($old);
}

sub content_type {
    my $self = shift;
    my $ct   = $self->header('content-type');
    $self->header('content-type', shift) if @_;
    $ct = $ct->[0] if ref($ct) eq 'ARRAY';
    return '' unless defined($ct) && length($ct);
    my @ct = split( /;\s*/, $ct, 2 );
    for ( $ct[0] ) {
        s/\s+//g;
        $_ = lc($_);
    }
    wantarray ? @ct : $ct[0];
}

# This is copied here because it is not a method
sub _split_header_words
{
    my(@val) = @_;
    my @res;
    for (@val) {
	my @cur;
	while (length) {
	    if (s/^\s*(=*[^\s=;,]+)//) {  # 'token' or parameter 'attribute'
		push(@cur, $1);
		# a quoted value
		if (s/^\s*=\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\"//) {
		    my $val = $1;
		    $val =~ s/\\(.)/$1/g;
		    push(@cur, $val);
		# some unquoted value
		}
		elsif (s/^\s*=\s*([^;,\s]*)//) {
		    my $val = $1;
		    $val =~ s/\s+$//;
		    push(@cur, $val);
		# no value, a lone token
		}
		else {
		    push(@cur, undef);
		}
	    }
	    elsif (s/^\s*,//) {
		push(@res, [@cur]) if @cur;
		@cur = ();
	    }
	    elsif (s/^\s*;// || s/^\s+//) {
		# continue
	    }
	    else {
		die "This should not happen: '$_'";
	    }
	}
	push(@res, \@cur) if @cur;
    }

    for my $arr (@res) {
	for (my $i = @$arr - 2; $i >= 0; $i -= 2) {
	    $arr->[$i] = lc($arr->[$i]);
	}
    }
    return @res;
}

sub content_type_charset {
    my $self = shift;
    my $h = $self->header('content-type');
    $h = $h->[0] if ref($h);
    $h = "" unless defined $h;
    my @v = _split_header_words($h);
    if (@v) {
        my($ct, undef, %ct_param) = @{$v[0]};
        my $charset = $ct_param{charset};
        if ($ct) {
            $ct = lc($ct);
            $ct =~ s/\s+//;
        }
        if ($charset) {
            $charset = uc($charset);
            $charset =~ s/^\s+//;  $charset =~ s/\s+\z//;
            undef($charset) if $charset eq "";
        }
        return $ct, $charset if wantarray;
        return $charset;
    }
    return undef, undef if wantarray; ## no critic
    return undef; ## no critic
}

sub referer {
    my $self = shift;
    if ( @_ && $_[0] =~ /#/ ) {

        # Strip fragment per RFC 2616, section 14.36.
        my $uri = shift;
        if ( ref($uri) ) {
            require URI;
            $uri = $uri->clone;
            $uri->fragment(undef);
        }
        else {
            $uri =~ s/\#.*//;
        }
        unshift @_, $uri;
    }
    ( $self->header( 'Referer', @_ ) )[0];
}

sub _basic_auth {
    require MIME::Base64;
    my ( $self, $h, $user, $passwd ) = @_;
    my ($old) = $self->header($h);
    if ( defined $user ) {
        Carp::croak("Basic authorization user name can't contain ':'")
          if $user =~ /:/;
        $passwd = '' unless defined $passwd;
        $self->header(
            $h => 'Basic ' . MIME::Base64::encode( "$user:$passwd", '' ) );
    }
    if ( defined $old && $old =~ s/^\s*Basic\s+// ) {
        my $val = MIME::Base64::decode($old);
        return $val unless wantarray;
        return split( /:/, $val, 2 );
    }
    return;
}

1;

__END__

=pod

=encoding utf8

=head1 NAME

HTTP::XSHeaders - Fast XS Header library, replacing HTTP::Headers and
HTTP::Headers::Fast.

=head1 VERSION

Version 0.200000

=head1 SYNOPSIS

    # load once
    use HTTP::XSHeaders;

    # keep using HTTP::Headers or HTTP::Headers::Fast as you wish

=head1 ALPHA RELEASE

This is a work in progress. Once we feel it is stable, the version will be
bumped to 1.0. Until then, feel free to use and try and submit tickets, but
do this at your own risk.

=head1 DESCRIPTION

By loading L<HTTP::XSHeaders> anywhere, you replace any usage
of L<HTTP::Headers> and L<HTTP::Headers::Fast> with a fast C implementation.

You can continue to use L<HTTP::Headers> and L<HTTP::Headers::Fast> and any
other module that depends on them just like you did before. It's just faster
now.

=head1 WHY

First there was L<HTTP::Headers>. It's good, stable, and ubiquitous. However,
it's slow.

Along came L<HTTP::Headers::Fast>. Gooder, stable, and used internally by
L<Plack>, so you know it means business.

Not fast enough, we implemented an XS version of it, released under the name
L<HTTP::Headers::Fast::XS>. It was a successful experiment. However, we
thought we could do better.

L<HTTP::XSHeaders> provides a complete rework of the headers library with the
intent of being fast, lean, and clear. It does not attempt to implement the
original algorithm, but instead uses its own C-level implementation with an
interface that is mostly compatible with both L<HTTP::Headers> and
L<HTTP::Headers::Fast>.

This module attempts to replace C<HTTP::Headers>, C<HTTP::Headers::Fast>,
and the XS implementation of it, C<HTTP::Headers::Fast::XS>. We attempt to
continue developing this module and perhaps deprecate
C<HTTP::Headers::Fast::XS>.

=head1 COMPATIBILITY

While we keep compatibility with the interfaces of L<HTTP::Headers> and
L<HTTP::Headers::Fast>, we've taken the liberty to make several changes that
were deemed reasonable and sane:

=over 4

=item * Aligning in C<as_string> method

C<as_string> method does weird stuff in order to keep the original
indentation. This is unnecessary and unhelpful. We simply add one space as
indentation after the first newline.

=item * No messing around in header names and casing

The headers are stored as given (C<MY-HeaDER> stays C<MY-HeaDER>) and
compared as lowercase. We do not uppercase or lowercase anything (other
than for comparing header names internally).

=item * Case normalization using leading colon is not supported

Following the previous item, we also do not normalize based on leading colon.

=item * C<$TRANSLATE_UNDERSCORE> is not supported

C<$TRANSLATE_UNDERSCORE> (which controls whether underscores are translated or
not) is not supported. It's barely documented (or isn't at all), it isn't
used by anything on CPAN, nor can we find any use-case other than the tests.
So, instead, we always convert underscores to dashes.

=item * L<Storable> is loaded but not used

Both L<HTTP::Headers> and L<HTTP::Headers::Fast> use L<Storable> for cloning.
While C<HTTP::Headers> loads it automatically, C<HTTP::Headers::Fast> loads
it lazily.

Since we override both, we load C<Storable> always. However, we do not use
it for cloning and instead implemented our C-level struct cloning.

=back

=head1 BENCHMARKS

    HTTP::Headers 6.05, HTTP::Headers::Fast 0.19, HTTP::XSHeaders 0.200000

    -- as_string
    Implementation  Time
    xsheaders       0.00468778222396934
    fast            0.0964434631535363
    orig            0.105793242864311

    -- as_string_without_sort
    Implementation            Time
    xsheaders_as_str          0.00475378949036912
    xsheaders_as_str_wo       0.00484256407093758
    fast_as_str               0.0954295831126767
    fast_as_str_wo            0.0736790240349744
    orig                      0.105823918835043

    -- get_content_length
    Implementation  Time
    xsheaders       0.0105355231679
    fast            0.0121647090348415
    orig            0.0574727505777773

    -- get_date
    Implementation  Time
    xsheaders       0.077750453123065
    fast            0.0826203668485442
    orig            0.101090469267193

    -- get_header
    Implementation  Time
    xsheaders       0.00505807073565111
    fast            0.0612525710276364
    orig            0.0820842156588862

    -- push_header
    Implementation  Time
    xsheaders       0.00271070907120684
    fast            0.0178986201816726
    orig            0.0242003530752845

    -- push_header_many
    Implementation  Time
    xsheaders       0.00426636619488888
    fast            0.0376390665501822
    orig            0.0503843871625857

    -- scan
    Implementation  Time
    xsheaders       0.0142865143596716
    fast            0.061759048917916
    orig            0.0667217048891246

    -- set_date
    Implementation  Time
    xsheaders       0.114970609213125
    fast            0.130542749562301
    orig            0.168121156055091

    -- set_header
    Implementation  Time
    xsheaders       0.0456117003715809
    fast            0.0868535344701981
    orig            0.135920422020881

=head1 METHODS

These match the API described in L<HTTP::Headers> and L<HTTP::Headers::Fast>,
with caveats described above in B<COMPATIBILITY>.

=head2 new

Create a new object.

=head2 clone

Create a new object from this object's headers.

=head2 header

Get or set a header.

=head2 clear

Clears all headers.

=head2 push_header

Add a header value.

=head2 init_header

Initialize a header.

=head2 remove_header

Removes a header.

=head2 remove_content_headers

Removes all content headers.

=head2 as_string

Returns a sorted string representation of all headers.

=head2 as_string_without_sort

Returns a non-sorted string representation of all headers.

=head2 header_field_names

Returns all header field names.

=head2 scan

Apply a function to each header value.

=head2 content_type

Get the content type header.

=head2 content_type_charset

Get the content type charset header.

=head2 referer

Get or set the referer header.

=head2 referrer

Same as C<referer> but in proper English (unlike the HTTP spec).

=head1 AUTHORS

=over 4

=item * Gonzalo Diethelm C<< gonzus AT cpan DOT org >>

=item * Sawyer X C<< xsawyerx AT cpan DOT org >>

=back

=head1 THANKS

=over 4

=item * Rafaël Garcia-Suarez

=item * p5pclub

=back
