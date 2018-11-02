#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use 5.10.0;
use Data::Dumper;
use CGI::Fast;
use Readonly;
use TwitRSS;

Readonly my $OWN_BASEURL => 'http://twitrss.me/twitter_user_to_rss';

while (my $q = CGI::Fast->new) {
        my @ps = $q->param;
        my $bad_param=0;
        for(@ps) {
          unless ($_=~/^(fetch|replies|user)$/) {
            err("Bad parameters. Naughty.",404);
            $bad_param++;
            last;
          }
        }
        next if $bad_param;

  my $user = $q->param('user') || 'ciderpunx';

  $user = lc $user;
  if($user =~ '^#') {
    err("That was an hashtag, TwitRSS.me only supports users!",404);
    next;
  }
  $user=~s/(@|\s|\?)//g;
  $user=~s/%40//g;

  my $replies = $q->param('replies') || 0;
  if ($replies && lc($replies) ne 'on') {
          err("Bad parameters. Naughty.",404);
          $bad_param++;
          next;
  }

  my $content     = fetch_user_feed($user, $replies);
  my @items       = items_from_feed($content);
  my $feed_url    = "$OWN_BASEURL/?user=$user";
  $feed_url       .= '&replies=on' if $replies;
  my $feed_title  = "Twitter Search / $user";
  my $twitter_url = "$TWITTER_BASEURL/$user";
  $twitter_url    .= '/with_replies' if $replies;
  display_feed($feed_url, $feed_title, $twitter_url, @items);
}
