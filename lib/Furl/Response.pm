package Furl::Response;
use strict;
use warnings;
use utf8;
use Furl::Headers;

sub new {
    my ($class, $minor_version, $code, $message, $headers, $content, $request) = @_;
    bless {
        minor_version => $minor_version,
        code    => $code,
        message => $message,
        headers => Furl::Headers->new($headers),
        content => $content,
        request => $request,
    }, $class;
}

# accessors
sub code    { shift->{code} }
sub message { shift->{message} }
sub headers { shift->{headers} }
sub content { shift->{content} }
sub request { shift->{request} }

# alias
sub status { shift->code() }
sub body   { shift->content() }

# shorthand
sub content_length   { shift->headers->content_length() }
sub content_type     { shift->headers->content_type() }
sub content_encoding { shift->headers->content_encoding() }
sub header           { shift->headers->header(@_) }

sub protocol { "HTTP/1." . $_[0]->{minor_version} }

sub decoded_content {
    my $self = shift;
    $self->as_http_response->decoded_content(@_);
}

sub as_http_response {
    my ($self) = @_;
    require HTTP::Response;
    my $res = HTTP::Response->new( $self->code, $self->message,
        [ $self->headers->flatten ],
        $self->content );
    $res->protocol($self->protocol);

    if (my $req = $self->request) {
        $res->request($req->as_http_request);
    }

    return $res;
}

sub to_psgi {
    my ($self) = @_;
    return [
        $self->code,
        [$self->headers->flatten],
        [$self->content]
    ];
}

sub as_hashref {
    my $self = shift;

    return +{
        code    => $self->code,
        message => $self->message,
        protocol => $self->protocol,
        headers => [$self->headers->flatten],
        content => $self->content,
    };
}

sub is_success { substr( $_[0]->code, 0, 1 ) eq '2' }
sub status_line { $_[0]->code . ' ' . $_[0]->message }

sub charset {
    my $self = shift;

    return $self->{__charset} if exists $self->{__charset};
    if ($self->can('content_charset')){
        # To suppress:
        # Parsing of undecoded UTF-8 will give garbage when decoding entities
        local $SIG{__WARN__} = sub {};
        my $charset = $self->content_charset;
        $self->{__charset} = $charset;
        return $charset;
    }

    my $content_type = $self->headers->header('Content-Type');
    return unless $content_type;
    $content_type =~ /charset=([A-Za-z0-9_\-]+)/io;
    $self->{__charset} = $1 || undef;

    # Detect charset from HTML
    unless (defined($self->{__charset}) && $self->content_type =~ m{text/html}) {
        # I guess, this is not so perfect regexp. patches welcome.
        #
        # <meta http-equiv="Content-Type" content="text/html; charset=EUC-JP"/>
        $self->content =~ m!<meta\s+http-equiv\s*=["']Content-Type["']\s+content\s*=\s*["']text/html;\s*charset=([^'">/]+)['"]\s*/?>!smi;
        $self->{__charset} = $1;
    }

    $self->{__charset};
}

sub encoder {
    require Encode;
    my $self = shift;
    return $self->{__encoder} if exists $self->{__encoder};
    my $charset = $self->charset or return;
    my $enc = Encode::find_encoding($charset);
    $self->{__encoder} = $enc;
}

sub encoding {
    my $enc = shift->encoder or return;
    $enc->name;
}

1;
__END__

=head1 NAME

Furl::Response - Response object for Furl

=head1 SYNOPSIS

    my $res = Furl::Response->new($minor_version, $code, $message, $headers, $content);
    print $res->status, "\n";

=head1 DESCRIPTION

This is a HTTP response object in Furl.

=head1 CONSTRUCTOR

    my $res = Furl::Response->new($minor_version, $code, $msg, \%headers, $content);

=head1 INSTANCE METHODS

=over 4

=item $res->code

=item $res->status

Returns HTTP status code.

=item $res->message

Returns HTTP status message.

=item $res->headers

Returns instance of L<Furl::Headers>

=item $res->content

=item $res->body

Returns response body in scalar.

=item $res->decoded_content

This will return the content after any C<< Content-Encoding >> and charsets have been decoded. See L<< HTTP::Message >> for details

=item $res->request

Returns instance of L<Furl::Request> related this response.

=item $res->content_length

=item $res->content_type

=item $res->content_encoding

=item $res->header

Shorthand to access L<Furl::Headers>.

=item $res->protocol

    $res->protocol(); # => "HTTP/1.1"

Returns HTTP protocol in string.

=item $res->as_http_response

Make instance of L<HTTP::Response> from L<Furl::Response>.

=item $res->to_psgi()

Convert object to L<PSGI> response. It's very useful to make proxy.

=item $res->as_hashref()

Convert resopnse object to HashRef.

Format is following:

    code: Int
    message: Str
    protocol: Str
    headers: ArrayRef[Str]
    content: Str

=item $res->is_success

Returns true if status code is 2xx.

=item $res->status_line

    $res->status_line() # => "200 OK"

Returns status line.

=back
