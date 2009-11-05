# BEGIN BPS TAGGED BLOCK {{{
#
# COPYRIGHT:
#
# This software is Copyright (c) 1996-2007 Best Practical Solutions, LLC
#                                          <jesse@bestpractical.com>
#
# (Except where explicitly superseded by other copyright notices)
#
#
# LICENSE:
#
# This work is made available to you under the terms of Version 2 of
# the GNU General Public License. A copy of that license should have
# been provided with this software, but in any event can be snarfed
# from www.gnu.org.
#
# This work is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA
# 02110-1301 or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.
#
#
# CONTRIBUTION SUBMISSION POLICY:
#
# (The following paragraph is not intended to limit the rights granted
# to you to modify and distribute this software under the terms of
# the GNU General Public License and is only of importance to you if
# you choose to contribute your changes and enhancements to the
# community by submitting them to Best Practical Solutions, LLC.)
#
# By intentionally submitting any modifications, corrections or
# derivatives to this work, or any other work intended for use with
# Request Tracker, to Best Practical Solutions, LLC, you confirm that
# you are the copyright holder for those contributions and you grant
# Best Practical Solutions,  LLC a nonexclusive, worldwide, irrevocable,
# royalty-free, perpetual, license to use, copy, create derivative
# works based on those contributions, and sublicense and distribute
# those contributions and any derivatives thereof.
#
# END BPS TAGGED BLOCK }}}

=head1 NAME

  RT::ScripAction::EscalatePriority

=head1 description

EscalatePriority is a ScripAction which is NOT intended to be called
per transaction. It's intended to be called by an RT escalation tool.
One such tool is called rt-crontool and is located in $RTHOME/bin (see
C<rt-crontool -h> for more details)

EsclatePriority uses the following formula to change a ticket's priority:

    Priority = Priority +  (( final_priority - Priority ) / ( DueDate-Today))

Unless the duedate is past, in which case priority gets bumped straight
to final priority.

In this way, priority is either increased or decreased toward the final priority
as the ticket heads toward its due date.


=cut

package RT::ScripAction::EscalatePriority;
use base 'RT::ScripAction';

use strict;

#Do what we need to do and send it out.

#What does this type of Action does

sub describe {
    my $self = shift;
    return ( ref $self . " will move a ticket's priority toward its final priority." );
}


sub prepare {
    my $self = shift;

    if ( $self->ticket_obj->priority() == $self->ticket_obj->final_priority() ) {

        # no update necessary.
        return 0;
    }

    #compute the number of days until the ticket is due
    my $due = $self->ticket_obj->due;

    # If we don't have a due date, adjust the priority by one
    # until we hit the final priority
    if ( $due->epoch < 1 ) {
        if ( $self->ticket_obj->priority > $self->ticket_obj->final_priority ) {
            $self->{'prio'} = ( $self->ticket_obj->priority - 1 );
            return 1;
        } elsif ( $self->ticket_obj->priority < $self->ticket_obj->final_priority ) {
            $self->{'prio'} = ( $self->ticket_obj->priority + 1 );
            return 1;
        }

        # otherwise the priority is at the final priority. we don't need to
        # Continue
        else {
            return 0;
        }
    }

    # we've got a due date. now there are other things we should do
    else {
        my $diff_in_seconds = $due->diff( time() );
        my $diff_in_days    = int( $diff_in_seconds / 86400 );

        #if we haven't hit the due date yet
        if ( $diff_in_days > 0 ) {

            # compute the difference between the current priority and the
            # final priority

            my $prio_delta = $self->ticket_obj->final_priority() - $self->ticket_obj->priority;

            my $inc_priority_by = int( $prio_delta / $diff_in_days );

            #set the ticket's priority to that amount
            $self->{'prio'} = $self->ticket_obj->priority + $inc_priority_by;

        }

        #if $days is less than 1, set priority to final_priority
        else {
            $self->{'prio'} = $self->ticket_obj->final_priority();
        }

    }
    return 1;
}


sub commit {
    my $self = shift;
    my ( $val, $msg ) = $self->ticket_obj->set_priority( $self->{'prio'} );

    unless ($val) {
        Jifty->log->debug( $self . " $msg" );
    }
}

1;