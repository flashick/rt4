package RT::Action::UpdateTicket;
use strict;
use warnings;

use base qw/Jifty::Action::Record::Update/;

sub record_class { 'RT::Model::Ticket' }

use constant report_detailed_messages => 1;

sub arguments {
    my $self = shift;

    my $args = $self->SUPER::arguments();
    $args->{status}{valid_values} = $self->_compute_possible_statuses;
    $args->{queue}{valid_values} = $self->_compute_possible_queues;
    $args->{owner}{valid_values} = $self->_compute_possible_owners;
    return $args;
}

=head2 take_action

=cut

sub take_action {
    my $self        = shift;
    my @date_fields = qw/told starts started due/;

    foreach my $field (@date_fields) {
        my $value = $self->argument_value($field);
        if ( defined $value ) {

            # convert date to be as UTC
            my $date = RT::DateTime->new_from_string($value);
            $self->argument_value($field, $date);
        }
    }

    my @time_fields = qw/time_left time_estimated time_worked/;

    foreach my $field (@time_fields) {
        my $value = $self->argument_value($field);
        if ( defined $value ) {
            if ( $value =~ /([\d.]+)h(our)?/ ) {
                $value = int $1 * 60;
            }
            elsif ( $value =~ /(\d+)/ ) {
                $value = $1;
            }
            $self->argument_value( $field, $value );
        }
    }

    $self->SUPER::take_action;
    return 1;
}

sub _compute_possible_owners {
    my $self = shift;

    my @objects = ( $self->record, $self->record->queue );

    my %user_uniq_hash;

    my $isSU = Jifty->web->current_user->has_right(
        right  => 'SuperUser',
        object => RT->system
    );

    foreach my $object (@objects) {
        my $Users = RT::Model::UserCollection->new( current_user => $self->current_user );
        $Users->who_have_right(
            right                 => 'OwnTicket',
            object                => $object,
            include_system_rights => 1,
            include_superusers    => $isSU
        );
        while ( my $user = $Users->next() ) {
            next
              if ( $user->id == RT->nobody->id )
              ;    # skip nobody here, so we can make them first later
            $user_uniq_hash{ $user->id() } = $user;
        }
    }

    my $owners = [
        map { { display => $_->name, value => $_->id } }
          sort { uc( $a->name ) cmp uc( $b->name ) } values %user_uniq_hash
    ];
    unshift @$owners, { display => 'Nobody', value => RT->nobody->id };

    return $owners;
}

sub _compute_possible_queues {
    my $self = shift;

    my $q = RT::Model::QueueCollection->new( current_user => $self->current_user );
    $q->find_all_rows;

    my $queues;

    my $current_queue = $self->record->queue;
    push @$queues, {
        display => _('%1 (unchanged)', $current_queue->name),
        value => $current_queue->id,
    };

    while (my $queue = $q->next) {
        if (   $queue->current_user_has_right('CreateTicket')
            && $queue->id ne $current_queue->id )
        {
            push @$queues, { display => $queue->name, value => $queue->id };
        }
    }

    return $queues;
}

sub _compute_possible_statuses {
    my $self = shift;

    my $record = $self->record;
    return [
        map { { display => $_, value => $_ } }
        $record->status,
        $record->queue->status_schema->transitions( $record->status )
    ];
}

1;