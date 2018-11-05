package TwitRSSMojo;

use 5.22.0;
use warnings;

use Mojo::Base              qw( Mojolicious );
use Mojo::Log               qw( );
use Mojo::UserAgent         qw( );
use TwitRSS                 qw(
    items_from_feed render_feed search_feed_url user_feed_url
);

use Function::Parameters    qw( :strict );

my $log = Mojo::Log->new;
my $ua  = Mojo::UserAgent->new;

method startup() {
    #$self->static->paths([qw( /twitrssme/static )]);
    $self->routes->get('/search/:query'  => \&twitter_search);
    $self->routes->get('/user/:username' => \&twitter_user);
}

fun twitter_search($c) {
    my $query = $c->param('query');
    my $twitter_url = search_feed_url($query);
    my $feed_title  = "Twitter search for $query";
    my $feed_url    = "http://twitrss.me/search/$query";

    $ua->get_p($twitter_url)->then(fun ($tx) {
        my $content = $tx->result->body;
        my $items = items_from_feed($content);
        my $rss = render_feed($feed_url, $feed_title, $twitter_url, $items);
        $c->render(format => 'rss', data => $rss);
    })->catch(fun($err) {
        $log->error("Fetching $twitter_url: $err");
        $c->render(text => $err);
    });

    $c->render_later;
};

fun twitter_user($c) {
    my $user = $c->param('username');
    my $twitter_url = user_feed_url($user);
    my $feed_title  = "Twitter search for \@$user";
    my $feed_url    = "http://twitrss.me/user/$user";

    $ua->get_p($twitter_url)->then(fun ($tx) {
        my $content = $tx->result->body;
        my $items = items_from_feed($content);
        my $rss = render_feed($feed_url, $feed_title, $twitter_url, $items);
        $c->render(format => 'rss', data => $rss);
    })->catch(fun($err) {
        $log->error("Fetching $twitter_url: $err");
        $c->render(text => $err);
    });

    $c->render_later;
};

1;
