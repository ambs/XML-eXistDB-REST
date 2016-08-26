
use warnings;
use strict;
use Test::More;
use XML::eXistDB::REST;

if( !exists($ENV{EXISTDB_REST_SERVER})  || 
	!exists($ENV{EXISTDB_REST_USER})    ||
	!exists($ENV{EXISTDB_REST_PASSWORD}) ) {
    
      plan skip_all => 'No eXistDB configured for testing. See INSTALL for details.';
}
## FIXME: do timeout, and skip all tests!
my $rest = XML::eXistDB::REST->new();

isa_ok($rest => 'XML::eXistDB::REST', "We have an object");

my $collection = $rest->get("/db");
isa_ok($collection => 'XML::eXistDB::REST::Collection', 'query to obtain collection');

my $tests = $collection->get("tests");
isa_ok($tests => 'XML::eXistDB::REST::Collection', 'query to obtain collection');

my $content = _load_file("t/sample.xml");
$tests->put( $content => "sample.xml");

ok($tests->contains("sample.xml"));

$tests->delete("sample.xml");
ok(!$tests->contains("sample.xml"));
	


done_testing();


sub _load_file {
	my $f = shift;
	local $/;
	undef $/;
	open my $fh, "<", $f or die;
	my $c = <$fh>;
	close $fh;
	return $c;
}