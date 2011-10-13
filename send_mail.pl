#!/usr/bin/perl -w
use strict;
use Getopt::Std;
use Net::Ping;
use Net::SMTP::SSL;
use Text::Iconv;
use MIME::Base64;
use Socket;

my %opt=();
getopts("t:f:m:a:hks", \%opt);

sub help
{
  print "Usage: $0 [-h] [-k] [-a E-MAIL] [-t SUBJECT] -f TXTFILE |-m MESSAGE | -s STDOUT\n\t-h\tПоказывает эту справку.\n\t-k\tНужно указывать если текст в KOI8-R. По умолчанию работает в UTF-8.\n\t-a\tможно указать адрес\n";
  exit;
}

if (defined $opt{h})
{
  help();
}


sub wlog
{
  my $time = localtime;
  my $log_file = 'log';                                        # Куда писать логи
  open LOG, ">>$log_file" or die("$log_file: $!");
  print LOG "${time}: $_[0]\n";
  close LOG or die("$log_file: $!");
  print STDERR "${time}: $_[0]\n";
  return 1;
}

sub derr
{
  wlog("(E) $_[0]");
  wlog("DIE\n");
  die("$_[0]");
  return;
}

sub conv
{
  if (defined $opt{k})
  {
    my $cnvt = Text::Iconv->new("KOI8-R", "UTF-8");
    foreach (@_)
    {
      $_ = $cnvt->convert($_);
    }
  }
  return 1;
}

sub mail_send
{
  my ($subject, $message) = @_;
  my $list_mail = '~/.My/send_mail/list';     # Файл со списком почтовых ящиков
  conv($subject);                                       # Конвертируем в KOI8-R
  $subject = '=?UTF-8?B?' . MIME::Base64::encode_base64($subject, '') . '?=';
  conv($message);                                       # Конвертируем в KOI8-R
  $message = MIME::Base64::encode_base64($message, '');
###
  wlog("(I) Пишем письмо");
  my $smtp_server = 'smtp.gmail.com';
  my $smtp_port = '465';

  my $mail = 'googleuser@gmail.com';
  my $user = 'googleuser@gmail.com';
  my $password = 'googlepassword';

  my @recipient;
  unless (defined $opt{a})
  {
     open SOAP, "<$list_mail" or derr("$list_mail: $!");
     while(<SOAP>)
     {
       if(/\s*\#/)
       {
         next;
       }
       elsif(/[-\w\.]*\@[-\w\.]*/)
       {
          @recipient = (@recipient, $&);
       }
     }
     close SOAP or derr("$list_mail: $!");
  }
  else
  {
     @recipient = $opt{a};
  }
###
   my $smtp = Net::SMTP::SSL->new($smtp_server, Port=>$smtp_port, Debug=>0) or derr("$@");
   $smtp->auth($user, $password) or derr("$@");
   $smtp->mail($mail) or derr("$@");
   $smtp->recipient(@recipient) or derr("$@");
   $smtp->data() or derr("$@");
   $smtp->datasend("MIME-Version: 1.0\n") or derr("$@");
   $smtp->datasend("Content-Type: text/plain; charset=UTF-8\n") or derr("$@");
   $smtp->datasend("Content-transfer-encoding: Base64\n") or derr("$@");
   $smtp->datasend("Subject: $subject\n") or derr("$@");
   my $to = $recipient[0];
   for(my $i = 1; $i < scalar @recipient; $i++)
   {
      $to = $to.", ".$recipient[$i];
   }
   $smtp->datasend("To: $to\n") or derr("$@");
   $smtp->datasend("\n") or derr("$@");
   $smtp->datasend("$message\n") or derr("$@");
   $smtp->dataend() or derr("$@");
   $smtp->quit() or derr("$@");
  wlog("(I) Письмо отправлено");
  return 1;
}
my $subj;
my $msg;

wlog("ПОЕХАЛИ!");

if (defined $opt{m} && !defined $opt{f} && !defined $opt{s})
{
   $subj = $opt{t};
   $msg = $opt{m}
}
elsif (!defined $opt{m} && defined $opt{f} && !defined $opt{s})
{
  $subj = $opt{t};
  open HAF, "<$opt{f}" or derr("$opt{f}: $!");
  while(<HAF>)
  {
    $msg = $msg.$_;
  }
  close HAF or derr("$opt{f}: $!");
}
elsif (!defined $opt{m} && !defined $opt{f} && defined $opt{s})
{
  $subj = $opt{t};
  while(<>)
  {
    $msg = $msg.$_;
  }
}
else
{
  help();
}

unless (defined $opt{t})
{
  $subj = $msg;
  $subj =~ s/\n/ \\n /g;
  $subj = substr($subj, 0, 76);
  wlog("(W) Сообщение без темы");
}
mail_send($subj, $msg);
wlog("КОНЕЦ\n");

