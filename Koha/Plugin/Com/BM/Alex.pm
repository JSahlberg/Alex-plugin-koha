package Koha::Plugin::Com::BM::Alex;

## It's good practice to use Modern::Perl
use Modern::Perl;

## Required for all plugins
use base qw ( Koha::Plugins::Base );

## We will also need to include any Koha libraries we want to access
use utf8;
use C4::Auth;
use C4::Context;
use Koha::Biblios;

use CGI qw ( -utf8 );
use HTML::Entities;
use strict;
use warnings;

use Koha::DateUtils;

use HTTP::Request;
use XML::Simple;
use XML::LibXML;

use LWP::UserAgent;
use Mojo::JSON qw ( decode_json encode_json );

## Here we set our plugin version
our $VERSION = "1.2.1";


## Here is our metadata, some keys are required, some are optional
our $metadata = {
  name            => 'Alex författarlexikon',
  author          => 'Johan Sahlberg',
  date_authored   => '2022-11-01',
  date_updated    => "2023-09-19",
  minimum_version => "20.11",
  maximum_version => undef,
  version         => $VERSION,
  description     => 'Alex författarlexikon plugin',
};

sub new {
  my ( $class, $args ) = @_;

  $args->{'metadata'} = $metadata;
  $args->{'metadata'}->{'class'} = $class;

  my $self = $class->SUPER::new($args);

  return $self;
}


## If your plugin needs to add some CSS to the staff intranet, you'll want
## to return that CSS here. Don't forget to wrap your CSS in <style>
## tags. By not adding them automatically for you, you'll have a chance
## to include external CSS files as well!
sub intranet_head {
  my ( $self ) = @_;

  return q|
    <style>
      /* ALEX */

      #alextd {
        /*  max-width: 200px; */
        float: right;
        border: 1px solid #e58a37;
        border-radius: 3px;
        box-shadow: 0 4px 8px 0 rgba(0, 0, 0, 0.2), 0 6px 20px 0 rgba(0, 0, 0, 0.19);
        padding: 10px;
        z-index: 1;
      }

      #alextd table, #alextd td {
        border: none;
        background-color: #fff;
      }

      #closeAlex {
        position: absolute;
        display: inline;
        right: 2px;
        top: 0px;
        font-size: large;
        color: #999;
        cursor: pointer;
        padding: 0 0 30px 30px;
      }

      #closeAlex:hover {
        color: #d00;
      }

      #openAlex {
          color: #666;
          cursor: pointer;
      }

    </style>
  |;
}


sub opac_head {
    my ( $self ) = @_;

    return q|
        <style>
          
        </style>
    |;
}



## If your plugin needs to add some javascript in the staff intranet, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.

sub intranet_js {
  my ( $self ) = @_;

  my $query = CGI->new();

  my $url = $query->url(-absolute => 1); #vilken sida är vi på?
  my $prefurl = 'detail.pl'; #sidan som vi vill det ska exekveras på

  if (index($url, $prefurl) != -1) { # Kollar så vi är på rätt sida, dvs detail.pl

    if ( defined ( $query->param('biblionumber') ) ) { #Finns det ett biblionumber i url'en?
      my $biblio = Koha::Biblios->find( HTML::Entities::encode( $query->param('biblionumber') ) );
      my $marcrecord = $biblio->metadata->record;

      my $result;
      my $author;

      foreach my $tag (@{ $marcrecord->{_fields} }) { #Sök igenom alla fält i katalogposten
        if ($tag->{_tag} == "100") {
          my @subfields = $tag->{_subfields};
          my $indexnr = grep { $subfields[$_] == /a/ } 0..$#subfields;
          $author = $tag->{_subfields}->[$indexnr + 1] // '';
          last; #Avsluta sökandet om fält 100 har hittats
        }
      }

      if ( $author ) {

        #my $desc;

        my $meta = $self->get_meta($author);

        if (!defined $meta) {
          return q|
            <script>
              console.log('(Alex) Ingen data tillgänglig!');
            </script>
          |;
        } else {

          my $found = $meta->{'response'}->{'writers'}->{'found'};
          my $writer = $meta->{'response'}->{'writers'}->{'writer'}->{'name'};
          my $article = $meta->{'response'}->{'writers'}->{'writer'}->{'article'};
          my $imageUrl = $meta->{'response'}->{'writers'}->{'writer'}->{'imageUrl'};
          my $imageText = $meta->{'response'}->{'writers'}->{'writer'}->{'imageText'};
          my $bornDeadText = $meta->{'response'}->{'writers'}->{'writer'}->{'bornDeadText'};
          my $alexLogotype = $meta->{'response'}->{'writers'}->{'writer'}->{'alexLogotype'};
          my $alexLinkUrl = $meta->{'response'}->{'writers'}->{'writer'}->{'alexLinkUrl'};
          $article =~ s/\R//g; #Ta bort onödiga radbrytningar
          $article =~ s/'//g;


          if ($found == '1') {

            return q|
              <script>
                
                var alexFound = '| . $found . q|';
                var alexArticle = '| . $article . q|';
                var alexImageUrl = '| . $imageUrl  . q|';
                var alexImageText = '| . $imageText  . q|';
                var alexName = '| . $writer  . q|';
                var alexBornDeadText = '| . $bornDeadText  . q|';
                var alexLogotype = '| . $alexLogotype  . q|';
                var alexLinkUrl = '| . $alexLinkUrl  . q|';



                function getAlex() {

                  if (alexFound == '1') {
                    alexArticle = alexArticle.toString().trim();
                    if (alexArticle.slice(-2).indexOf('.') == -1) {
                      alexArticle = alexArticle.concat('...');
                    }
                    alexImageUrl = alexImageUrl.toString();
                    if (alexImageUrl.indexOf('noimage') > -1) {
                      alexImageUrl = '';
                      alexImageText = '';
                    } else {
                      alexImageText = alexImageText.toString();
                      if (alexImageText.indexOf('[object]') > -1) {
                        alexImageText = '';
                      }
                    }

                    alexName = alexName.toString();
                    alexBornDeadText = alexBornDeadText.toString();
                    alexLogotype = alexLogotype.toString();
                    alexLinkUrl = alexLinkUrl.toString();
                  }
                  $('<div id="alexdone" style="display:none"></div>').appendTo('body');
                  if (alexFound == '1') {
                    alexDivDetail();
                  }
                  $('#alexdone').remove();
                };

                function alexDiv(element) {
                  $('<div class="previewbox" style="position:absolute;display:inline;border:solid 1px #d0d0d0;right:unset;bottom:unset;"><div id="alexwindow" style="width:600px;height:160px;margin:20px;"><div style="float:left;"><img src="' + alexImageUrl + '" height="190px" style="display:block;padding-right:10px"><span style="font-size:smaller;">' + alexImageText + '</span></div><h3 class="author">' + alexName + '</h3><h5>' + alexBornDeadText + '</h5><br /><span><span>' + alexArticle + '</span><br /><span style="display:block;float:right;padding-top:5px;">(Mer information finns på Alex.se)</span></div><div style="float:right;padding:0 10px 10px 0"><img src="' + alexLogotype + '" style="float:right;width:80px;"></div></div>').insertAfter(element);
                };

                function alexDivDetail() {
                  $('<div id="alextd" style="max-width:400px;float:right;position:absolute;display:inline;right:18px;background-color:#fff"></div>').insertBefore('#catalogue_detail_biblio');

                  $('#alextd').append('<div id="alexwindow"></div>');

                  $('#alextd').append('<span id="openAlex">Visa Alex</span>');
                  $('#openAlex').hide();

                  $('#alexwindow').append('<table id="alexTable"><tbody><tr></tr></tbody></table>');

                  $('#alextd').on('click', function() {
                    $('#alexwindow').toggle();
                    $('#openAlex').toggle();
                  });

                  $('#alexwindow tr').append('<td id="alexInfo"></td>');
                  $('#alexInfo').append('<h5 class="author">' + alexName + '</h5>');
                  $('#alexInfo').append('<h5 style="font-size:85%">' + alexBornDeadText + '</h5>');
                  $('#alexInfo').append('<span id="alexArticle" class="results_summary" style="font-size:85%"></span>');
                  $('#alexArticle').html(alexArticle);
                  $('#alexInfo').append('<span class="results_summary"><a href="' + alexLinkUrl + '" target="_blank">Läs mer på Alex.se</a></span>');
                  $('#alexInfo').append('<div style="display:block;float:right"><img src="' + alexLogotype + '" style="width:80px;"></div>');
                  $('#alexwindow tr').append('<td id="alexImg"><img src="' + alexImageUrl + '" style="display:block;max-width:160px;padding:5px 3px 0 5px;"></td>');
                  $('#alexImg').append('<span class="results_summary" style="font-size:80%;padding-left:5px;">' + alexImageText + '</span>');

                  setTimeout(function() {
                    $('#alexwindow').hide(500);
                    $('#openAlex').show(200);
                  }, 2000);
                };

                getAlex(alexName);

              </script>
            |;
          } else {
            return q|
              <script>
                console.log('(Alex) Ingen info om författaren!');
              </script>
            |;
          }
        }
      } else {
        return q|
          <script>
            console.log('(Alex) Ingen författare i posten!');
          </script>
        |;
      }
    }
  } else {
    return q|
      <script>
        console.log('Alex plugin installed');
      </script>
    |;
  }
}



## If your plugin needs to add some javascript in the OPAC, you'll want
## to return that javascript here. Don't forget to wrap your javascript in
## <script> tags. By not adding them automatically for you, you'll have a
## chance to include other javascript files if necessary.
sub opac_js {
    my ( $self ) = @_;

  my $query = CGI->new();

  my $url = $query->url(-absolute => 1); #vilken sida är vi på?
  my $prefurl = 'opac-detail.pl'; #sidan som vi vill det ska exekveras på

  if (index($url, $prefurl) != -1) { # Kollar så vi är på rätt sida, dvs detail.pl

    if ( defined ( $query->param('biblionumber') ) ) { #Finns det ett biblionumber i url'en?
      my $biblionumber = $query->param('biblionumber'); #Deklarera biblionumber
      my $encbiblionumber = HTML::Entities::encode($biblionumber); #Koda om till läsbart
      my $biblio = Koha::Biblios->find( $encbiblionumber );
      #my $record = GetMarcBiblio({ biblionumber => $biblionumber }); #Hämta katalogposten
      my $marcrecord = $biblio->metadata->record;

      my $result;
      my $author;

      foreach my $tag (@{ $marcrecord->{_fields} }) { #Sök igenom alla fält i katalogposten
        if ($tag->{_tag} == "100") {
          my @subfields = $tag->{_subfields};
          my $indexnr = grep { $subfields[$_] == /a/ } 0..$#subfields;
          $author = $tag->{_subfields}->[$indexnr + 1] // '';
          last; #Avsluta sökandet om fält 100 har hittats
        }
      }

      if ( $author ) {

        my $desc;

        my $meta = $self->get_meta($author);

        if (!defined $meta) {
          return q|
            <script>
              console.log('(Alex) Ingen data tillgänglig!');
            </script>
          |;
        } else {

          my $found = $meta->{'response'}->{'writers'}->{'found'};
          my $writer = $meta->{'response'}->{'writers'}->{'writer'}->{'name'};
          my $article = $meta->{'response'}->{'writers'}->{'writer'}->{'article'};
          my $imageUrl = $meta->{'response'}->{'writers'}->{'writer'}->{'imageUrl'};
          my $imageText = $meta->{'response'}->{'writers'}->{'writer'}->{'imageText'};
          my $bornDeadText = $meta->{'response'}->{'writers'}->{'writer'}->{'bornDeadText'};
          my $alexLogotype = $meta->{'response'}->{'writers'}->{'writer'}->{'alexLogotype'};
          my $alexLinkUrl = $meta->{'response'}->{'writers'}->{'writer'}->{'alexLinkUrl'};
          if ( $article ) {
              $article =~ s/\R//g; #Ta bort onödiga radbrytningar
              $article =~ s/'//g;
          }


          if ($found == '1') {

            return q|
              <script>
                var alexFound = '| . $found . q|';
                var alexArticle = '| . $article . q|';
                var alexImageUrl = '| . $imageUrl  . q|';
                var alexImageText = '| . $imageText  . q|';
                var alexName = '| . $writer  . q|';
                var alexBornDeadText = '| . $bornDeadText  . q|';
                var alexLogotype = '| . $alexLogotype  . q|';
                var alexLinkUrl = '| . $alexLinkUrl  . q|';



                function getAlex() {

                  if (alexFound == '1') {
                    alexArticle = alexArticle.toString().trim();
                    if (alexArticle.slice(-2).indexOf('.') == -1) {
                      alexArticle = alexArticle.concat('...');
                    }
                    alexImageUrl = alexImageUrl.toString();
                    if (alexImageUrl.indexOf('noimage') > -1) {
                      alexImageUrl = '';
                      alexImageText = '';
                    } else {
                      alexImageText = alexImageText.toString();
                      if (alexImageText.indexOf('[object]') > -1) {
                        alexImageText = '';
                      }
                    }

                    alexName = alexName.toString();
                    alexBornDeadText = alexBornDeadText.toString();
                    alexLogotype = alexLogotype.toString();
                    alexLinkUrl = alexLinkUrl.toString();
                  }
                  $('<div id="alexdone" style="display:none"></div>').appendTo('body');
                  if (alexFound == '1') {
                    alexDivDetail();
                  }
                  $('#alexdone').remove();
                };

                function alexDivDetail() {
                  $('<div id="alexwindow" style="padding-top:15px"></div>').insertAfter('#ulactioncontainer');
                  $('#alexwindow').append('<div id="alexImg"><img src="'+ alexImageUrl +'" style="display:block;max-height:240px;"></div>');
                  $('#alexImg').append('<span class="results_summary" style="font-size:80%;">'+ alexImageText +'</span>');
                  $('#alexwindow').append('<h3 class="author">'+ alexName +'</h3>');
                  $('#alexwindow').append('<h5>'+ alexBornDeadText +'</h5>');
                  $('#alexwindow').append('<span class="results_summary" style="font-size:85%">' + alexArticle + '</span>');
                  $('#alexwindow').append('<span class="results_summary"><a href="'+ alexLinkUrl +'" target="_blank">Läs mer på Alex.se</a></span>');
                  $('#alexwindow').append('<div style="display:block;float:right"><img src="'+ alexLogotype +'" style="width:80px;"></div>');
                };

                getAlex(alexName);

              </script>
            |;
          } else {
            return q|
              <script>
                console.log('(Alex) Ingen info om författaren!');
              </script>
            |;
          }
        }
      } else {
        return q|
          <script>
            console.log('(Alex) Ingen författare i posten!');
          </script>
        |;
      }
    }
  } else {
    return q|
      <script>
        console.log('Alex plugin installed');
      </script>
    |;
  }    

}




## Subscript för att hämta metadata från Alex

sub get_meta {
    my ( $self, $args ) = @_;
    my $author = $args;

    ## Setup variables
    my $subkey = $self->retrieve_data('subscriptionKey');

    my $url = 'https://www.alex.se/partnerintegration/Writer/?Password=' . $subkey . '&Writer=' . $author;

    ##build the url
    my $request = HTTP::Request->new('GET', $url);

    ##Fetch the actual data from the query

    my $ua = LWP::UserAgent->new();
    $ua->agent("Perl API Client/1.0");
    my $response = $ua->request($request);

    if ($response->is_success) {

    ## Create the object of XML Simple
      my $xmlSimple = new XML::Simple(KeepRoot => 1);

    ## Load the xml file in object
      my $dataXML = $xmlSimple->XMLin($response->content);
      my $newXML = XML::LibXML->new();

    ## use encode json function to convert xml object in json.
      my $jsonString = encode_json($dataXML);
      my $decoded = decode_json($jsonString);

    ## finally return json
      return $decoded; #$jsonString;
    } else {
      return;
    }
}


## If your tool is complicated enough to needs it's own setting/configuration
## you will want to add a 'configure' method to your plugin like so.
## Here I am throwing all the logic into the 'configure' method, but it could
## be split up like the 'report' method is.
sub configure {
    my ( $self, $args ) = @_;
    my $cgi = $self->{'cgi'};

    unless ( $cgi->param('save') ) {
        my $template = $self->get_template({ file => 'configure.tt' });

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            subscriptionKey  => $self->retrieve_data('subscriptionKey'),
            last_upgraded    => $self->retrieve_data('last_upgraded'),
        );

        $self->output_html( $template->output() );
    }
    else {
        $self->store_data(
            {
                subscriptionKey => $cgi->param('subscriptionKey'),
                #last_configured_by => C4::Context->userenv->{'number'},
            }
        );
        $self->go_home();
    }
}

## This is the 'install' method. Any database tables or other setup that should
## be done when the plugin if first installed should be executed in this method.
## The installation method should always return true if the installation succeeded
## or false if it failed.
sub install() {
  my ( $self, $args ) = @_;
}

## This is the 'upgrade' method. It will be triggered when a newer version of a
## plugin is installed over an existing older version of a plugin
sub upgrade {
  my ( $self, $args ) = @_;

  #my $dt = dt_from_string();
  #$self->store_data( { last_upgraded => $dt->ymd('-') . ' ' . $dt->hms(':') } );

  #return 1;
}

## This method will be run just before the plugin files are deleted
## when a plugin is uninstalled. It is good practice to clean up
## after ourselves!
sub uninstall() {
        my ( $self, $args ) = @_;

}

1;
