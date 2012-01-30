package Noembed::Source::RapGenius;

use parent 'Noembed::Source';

use Web::Scraper;
use AnyEvent::HTTP;
use Encode;
use JSON;

sub prepare_source {
  my $self = shift;
  $self->{scraper} = scraper {
    process 'meta[property="og:title"]', title => '@content';
    process 'div.lyrics', 'id' => '@data-id';
    process 'div.lyrics', lyric => sub {
      my $node = $_[0]->clone;
      sub {
        my $id = shift;
        my $lyric = $node->look_down("data-id" => $id);
        $lyric ? scalar $lyric->as_text : "";
      }
    };
  }
}

sub patterns {
  'http://rapgenius\.com/[^/]+#note-(\d+)',
  'http://rapgenius\.com/(\d+)/[^/]+/[^/]+',
}
sub shorturls {'http://rapgenius\.com/\d+/?$'}
sub provider_name { "rapgenius" }

sub post_download {
  my ($self, $body, $callback) = @_;

  if ($body =~ /^window\.location = "\/([^"]+)"$/m) {
    http_request get => "http://rapgenius.com/$1", {
        recurse => 0,
        persistent => 0,
      },
      sub {
        my $body = decode "utf-8", shift;
        $self->get_definitions($body, $callback)
      };
  }
  else {
    $self->get_definitions($body, $callback);
  }
}

sub get_definitions {
  my ($self, $body, $callback) = @_;
  my $data = $self->{scraper}->scrape($body);

  http_request get => "http://rapgenius.com/annotations/for_song_page?song_id=$data->{id}", {
      persistent => 0,
      keepalive  => 0,
    },
    sub {
      my ($body, $headers) = @_;
      $data->{definitions} = $body;
      $callback->($data);
    };
}

sub serialize {
  my ($self, $data, $req) = @_;

  my $lyric_id = $req->captures->[0];
  my $lyric = $data->{lyric}->($lyric_id);
  my $tree = HTML::TreeBuilder->new_from_content($data->{definitions})->elementify;

  my $definition = do {
    my $node = $tree->look_down("data-id" => $lyric_id);
    my @images = $node->look_down("_tag" => "img");
    $_->attr("src" => $_->attr("data-src")) for @images;
    html($node->as_HTML(""));
  };

  $tree->delete;

  return {
    title => $data->{title},
    html => $self->render($data, $lyric, $definition),
  };
}

1;
