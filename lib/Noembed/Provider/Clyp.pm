package Noembed::Provider::Clyp;

use parent 'Noembed::oEmbedProvider';

sub provider_name {"Clyp"}
sub patterns {'https?://clyp\.it/.*'}
sub oembed_url {'https://api.clyp.it/oembed/'}

1;
