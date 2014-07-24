use Mojo::Base -strict;

use Test::More;
use Test::Mojo;
use Redis::Fast;
use Data::Dumper;
use Mojo::JSON 'j';
use utf8;

my $redis = Redis::Fast->new();
$redis->flushdb;

# dokechinさん入室
my $td = Test::Mojo->new('Chat::Web');

my $messages = sub {
    my ($t) = @_;
    my $m1 = $t->message_ok()->message;
    my $m2 = $t->message_ok()->message;

    my @sorted = sort { length($a) <=> length($b)} ($m1->[1],$m2->[1]);

    $t->message([text => $sorted[0]]);

    $t->json_message_is( "/names" => ["dokechin"]);

    $t->message([text => $sorted[1]]);
    
    $t->json_message_is( "/name" => "dokechin")
      ->json_message_like( "/hms" => qr/^\d\d:\d\d:\d\d$/)
      ->json_message_is( "/message" => '入室しました。');
};

$td->websocket_ok('/hoge/echo')
  ->send_ok('name	dokechin')
  ->$messages();

# ロビーにhogeルーム開設通知
my $tl = Test::Mojo->new('Chat::Web');

$tl->websocket_ok('/notify')
  ->send_ok('rooms')
  ->message_ok()
  ->json_message_is( "/rooms/0" => {name => "hoge"});

# papixさん入室
my $tp = Test::Mojo->new('Chat::Web');

$messages = sub {
    my ($t) = @_;
    my $m1 = $t->message_ok()->message;
    my $m2 = $t->message_ok()->message;

    my @sorted = sort { length($a) <=> length($b)} ($m1->[1],$m2->[1]);

    $t->message([text => $sorted[0]]);

    $t->json_message_is( "/names" => ["dokechin", "papix"]);

    $t->message([text => $sorted[1]]);
    
    $t->json_message_is( "/name" => "papix")
      ->json_message_like( "/hms" => qr/^\d\d:\d\d:\d\d$/)
      ->json_message_is( "/message" => '入室しました。');
};

$tp->websocket_ok('/hoge/echo')
  ->send_ok('name	papix')
  ->$messages();

# papixさん入室がdokechinさんに伝わる
$td->$messages();

# papixさんの発言がpapixさんへ伝わる
$tp->send_ok("message	yo")
  ->message_ok()
  ->json_message_is( "/name" => "papix")
  ->json_message_like( "/hms" => qr/^\d\d:\d\d:\d\d$/)
  ->json_message_is( "/message" => 'yo');

# papixさんの発言がdokechinさんへ伝わる
$td->message_ok()
  ->json_message_is( "/name" => "papix")
  ->json_message_like( "/hms" => qr/^\d\d:\d\d:\d\d$/)
  ->json_message_is( "/message" => 'yo')
  ->finish_ok;

# dokechinさんの退出がpapixさんへ伝わる

$messages = sub {
    my ($t) = @_;
    my $m1 = $t->message_ok()->message;
    my $m2 = $t->message_ok()->message;

    my @sorted = sort { length($a) <=> length($b)} ($m1->[1],$m2->[1]);

    $t->message([text => $sorted[0]]);

    $t->json_message_is( "/names" => ["papix"]);

    $t->message([text => $sorted[1]]);
    
    $t->json_message_is( "/name" => "dokechin")
      ->json_message_like( "/hms" => qr/^\d\d:\d\d:\d\d$/)
      ->json_message_is( "/message" => '退室しました');
};

$tp->$messages()
   ->finish_ok();

# ロビーにhogeルームの閉鎖が伝わる
$tl->message_ok()
  ->json_message_is( "/rooms/0" => undef)
  ->finish_ok;

done_testing();
