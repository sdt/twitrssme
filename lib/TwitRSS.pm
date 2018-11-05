package TwitRSS;

use 5.14.0;
use warnings;
use Data::Dumper;
use Readonly;
use HTML::TreeBuilder::XPath;
use HTML::TreeBuilder::LibXML;
use HTML::Entities qw(:DEFAULT encode_entities_numeric);
use Encode;
use POSIX qw(strftime);
use Exporter qw(import);
use Function::Parameters qw(:strict);

our @EXPORT = qw(user_feed_url search_feed_url items_from_feed render_feed err $TWITTER_BASEURL);

Readonly our $TWITTER_BASEURL    => 'https://twitter.com';
Readonly my  $MAX_AGE            => 3600;

HTML::TreeBuilder::LibXML->replace_original();

# fetch user feed
fun user_feed_url($user, $replies = undef) {
  # TODO: fixup $user?
  $user = lc $user;
  $user =~ s/@|\s|\?|%40//g;

  my $url = "$TWITTER_BASEURL/$user";
  $url .= "/with_replies" if $replies;

  return $url;
}

fun search_feed_url($term) {
  $term =~ s/^#//;
  $term =~ s/^%23//;

  my $url = "$TWITTER_BASEURL/search?f=tweets&vertical=default&q=$term&src=typd";
  return $url;
# TODO: Support hashtags
#  if ($term =~ m{^#}) {
#    $url = "$TWITTER_BASEURL/hashtag/$term?src=tren";
#  }
}

# parse search or user feed content, build up items array
# assumption: twitter keeps its tweet markup the same in searches and user feeds
# if not split this into 2 subs
fun items_from_feed($content) {
  my @items;

  my $tree= HTML::TreeBuilder::XPath->new;
  $tree->parse($content);
  my $tweets = $tree->findnodes( '//li' . class_contains('js-stream-item')); # new version 2015-06-02
  #say "called";
  #print Dumper $tweets;
  if ($tweets) {
    for my $li (@$tweets) {
      my $tweet = $li->findnodes('./div'
        . class_contains("js-stream-tweet")
      )->[0]
      ;
      next unless $tweet;
      my $header = $tweet->findnodes('./div/div'
        . class_contains("stream-item-header")
        . "/a"
        . class_contains("js-action-profile"))->[0];
      my $bd   = $tweet->findnodes( './div/div/p'
        . class_contains("js-tweet-text")
      )->[0];
      my $body = "<![CDATA[" . encode_entities($bd->as_HTML,'^\n\x20-\x25\x27-\x7e"') . "]]>";
      $body=~s{&amp;(\w+);}{&$1;}gi;
      $body=~s{href="/}{href="https://twitter.com/}gi; # add back in twitter.com to unbreak links to hashtags, users, etc.
      $body=~s{<a[^>]+href="https://t.co[^"]+"[^>]+title="([^"]+)"[^>]*>}{ <a href="$1">}gi;      # experimental! stop links going via t.co; if an a has a title use it as the href.
      $body=~s{<a[^>]+title="([^"]+)"[^>]+href="https://t.co[^"]+"[^>]*>}{ <a href="$1">}gi;      # experimental! stop links going via t.co; if an a has a title use it as the href.
      $body=~s{target="_blank"}{}gi;
      $body=~s{</?span[^>]*>}{}gi;
      $body=~s{</?s[^>]*>}{}gi;
      $body=~s{data-[\w\-]+="[^"]+"}{}gi; # validator doesn't like data-aria markup that we get from twitter
      my $avatar = $header->findvalue('./img' . class_contains("avatar") . "/\@src");
      my $fst_img_a = $tweet->findnodes( './div//div'
        . class_contains("js-adaptive-photo"))->[0];
      $fst_img_a = $tweet->findnodes( './div/div/div'
        . class_contains("OldMedia")
        . "/div/div/div")->[0] unless $fst_img_a;
      my $fst_img="";
      if($fst_img_a) {
        $fst_img = $fst_img_a->findvalue('@data-image-url');
        if($fst_img) {
          $body=~s{\]\]>$}{"<img src=\"$fst_img\" width=\"250\" />\]\]>"}e;
        }
      }
      my $fullname = $header->findvalue('./strong' . class_contains("fullname"));
      my $username = $header->findvalue('./span' . class_contains("username"));
      $username =~ s{<[^>]+>}{}g;
      $username =~ s{^\s+}{};
      $username =~ s{\s+$}{};
      my $title = enctxt($bd->as_text);
      $title=~s{&nbsp;}{}gi;
      $title=~s{http}{ http}; # links in title lose space
      my $uri = $TWITTER_BASEURL . $tweet->findvalue('@data-permalink-path');
      my $timestamp = $tweet->findnodes('./div/div'
        . class_contains("stream-item-header")
        . '/small/a'
        . class_contains("tweet-timestamp"))->[0]->findvalue('./span/@data-time'
      );

      my $pub_date = strftime("%a, %d %b %Y %H:%M:%S %z", localtime($timestamp));

      push @items, {
        username => enctxt($username),
        fullname => enctxt($fullname),
        link => $uri,
        guid => $uri,
        title => $title,
        description => $body,
        timestamp => $timestamp,
        pubDate => $pub_date,
      }
    }
  }
  else {
    $tree->delete;
    err("Can't gather tweets for that search",404);
    return;
  }
  $tree->delete;
  return \@items;
}

# print an rss feed, with header
fun render_feed($feed_url, $feed_title, $twitter_url, $items) {
  my $out = <<"ENDHEAD";
<?xml version="1.0" encoding="UTF-8"?>
<rss xmlns:atom="http://www.w3.org/2005/Atom" xmlns:georss="http://www.georss.org/georss" xmlns:twitter="http://api.twitter.com" xmlns:dc="http://purl.org/dc/elements/1.1/" version="2.0">
  <channel>
    <atom:link href="$feed_url" rel="self" type="application/rss+xml" />
    <title>$feed_title</title>
    <link>$twitter_url</link>
    <description>$feed_title</description>
    <language>en-us</language>
    <ttl>40</ttl>
ENDHEAD

  for (@$items) {
    $out .= <<"ENDITEM";
    <item>
      <title>$_->{title}</title>
      <dc:creator>$_->{fullname} ($_->{username})</dc:creator>
      <description>$_->{description}</description>
      <pubDate>$_->{pubDate}</pubDate>
      <guid>$_->{guid}</guid>
      <link>$_->{link}</link>
      <twitter:source/>
      <twitter:place/>
    </item>
ENDITEM
  }

  $out .= <<"ENDRSS";
  </channel>
</rss>
ENDRSS

  return $out;
}

# convenience: Encode entities
fun enctxt($text) {
  return encode_entities_numeric(decode_entities($text));
}

# convenience: Make XPATH class detection nicer
fun class_contains($classname) {
  return "[contains(concat(' ',normalize-space(\@class),' '),' $classname ')]";
}

# exit, printing an error
sub err {
  my ($msg,$status) = (shift,shift);
  print<<ENDHEAD
Content-type: text/html
Status: $status
Cache-control: max-age=86400
Refresh: 10; url=http://twitrss.me

<html><head></head><body><h2>ERR: $msg</h2><p>Redirecting you back to <a href="http://twitrss.me">TwitRSS.me</a> in a few seconds. You might have spelled the username wrong or something</p></body></html>
ENDHEAD
  ;
}

1;
