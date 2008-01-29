
use strict;
use warnings;
use RT::Test; use Test::More; 
plan tests => 11;
use RT;



{

my $q = RT::Model::Queue->new(current_user => RT->system_user);
$q->create(name =>'ownerChangeTest');

ok($q->id, "Created a scriptest queue");

my $s1 = RT::Model::Scrip->new(current_user => RT->system_user);
my ($val, $msg) =$s1->create( Queue => $q->id,
             ScripAction => 'User Defined',
             ScripCondition => 'On Owner Change',
             CustomIsApplicableCode => '',
             CustomPrepareCode => 'return 1',
             CustomCommitCode => '
                    $self->ticket_obj->set_Priority($self->ticket_obj->Priority+1);
                return(1);
            ',
             Template => 'Blank'
    );
ok($val,$msg);

my $ticket = RT::Model::Ticket->new(current_user => RT->system_user);
my ($tv,$ttv,$tm) = $ticket->create(Queue => $q->id,
                                    Subject => "hair on fire",
                                    initial_priority => '20'
                                    );
ok($tv, $tm);
ok($ticket->set_owner('root'));
is ($ticket->Priority , '21', "Ticket priority is set right");
ok($ticket->steal);
is ($ticket->Priority , '22', "Ticket priority is set right");
ok($ticket->untake);
is ($ticket->Priority , '23', "Ticket priority is set right");
ok($ticket->take);
is ($ticket->Priority , '24', "Ticket priority is set right");






}

1;
