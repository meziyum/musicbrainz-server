package MusicBrainz::Server::Controller::Release;
use Moose;
use MusicBrainz::Server::Track;

BEGIN { extends 'MusicBrainz::Server::Controller' }

with 'MusicBrainz::Server::Controller::Role::Annotation';
with 'MusicBrainz::Server::Controller::Role::Details';
with 'MusicBrainz::Server::Controller::Role::Relationship';
with 'MusicBrainz::Server::Controller::Role::EditListing';

__PACKAGE__->config(
    entity_name => 'release',
    model       => 'Release',
);

use MusicBrainz::Server::Controller::Role::Tag;

use MusicBrainz::Server::Constants qw(
    $EDIT_RELEASE_CHANGE_QUALITY
);

# A duration lookup has to match within this many milliseconds
use constant DURATION_LOOKUP_RANGE => 10000;

=head1 NAME

MusicBrainz::Server::Controller::Release - Catalyst Controller for
working with Release entities

=head1 DESCRIPTION

This controller handles user interaction, both read and write, with
L<MusicBrainz::Server::Release> objects. This includes displaying
releases, editing releases and creating new releases.

=head1 METHODS

=head2 base

Base action to specify that all actions live in the C<label>
namespace

=cut

sub base : Chained('/') PathPart('release') CaptureArgs(0) { }

after 'load' => sub
{
    my ($self, $c) = @_;
    my $release = $c->stash->{release};
    $c->model('Release')->load_meta($release);

    # Load release group
    $c->model('ReleaseGroup')->load($release);
    $c->model('ReleaseGroup')->load_meta($release->release_group);
    if ($c->user_exists) {
        $c->model('ReleaseGroup')->rating->load_user_ratings($c->user->id, $release->release_group);
    }

    # Load release group tags
    my $entity = $c->stash->{$self->{entity_name}};
    my @tags = $c->model('ReleaseGroup')->tags->find_top_tags(
        $release->release_group->id,
        $MusicBrainz::Server::Controller::Role::Tag::TOP_TAGS_COUNT);
    $c->stash->{top_tags} = \@tags;

    # We need to load more artist credits in 'show'
    if ($c->action->name ne 'show') {
        $c->model('ArtistCredit')->load($release);
    }
};

sub discids : Chained('load')
{
    my ($self, $c) = @_;

    my $release = $c->stash->{release};
    $c->model('Medium')->load_for_releases($release);
    $c->model('MediumFormat')->load($release->all_mediums);
    my @medium_cdtocs = $c->model('MediumCDTOC')->load_for_mediums($release->all_mediums);
    $c->model('CDTOC')->load(@medium_cdtocs);
    $c->stash( has_cdtocs => scalar(@medium_cdtocs) > 0 );
}

=head2 relations

Show all relationships attached to this release

=cut

sub relations : Chained('load')
{
    my ($self, $c) = @_;
    $c->stash->{relations} = $c->model('Relation')->load_relations($self->entity);
}

=head2 show

Display a release to the user.

This loads a release from the database (given a valid MBID or database row
ID) and displays it in full, including a summary of advanced relations,
tags, tracklisting, release events, etc.

=cut

sub show : Chained('load') PathPart('')
{
    my ($self, $c) = @_;

    my $release = $c->stash->{release};
    $c->model('ReleaseStatus')->load($release);
    $c->model('ReleasePackaging')->load($release);
    $c->model('Country')->load($release);
    $c->model('Language')->load($release);
    $c->model('Script')->load($release);
    $c->model('ReleaseLabel')->load($release);
    $c->model('Label')->load(@{ $release->labels });
    $c->model('ReleaseGroupType')->load($release->release_group);
    $c->model('Medium')->load_for_releases($release);

    my @mediums = $release->all_mediums;
    $c->model('MediumFormat')->load(@mediums);

    my @tracklists = grep { defined } map { $_->tracklist } @mediums;
    $c->model('Track')->load_for_tracklists(@tracklists);

    my @tracks = map { $_->all_tracks } @tracklists;
    my @recordings = $c->model('Recording')->load(@tracks);
    $c->model('Recording')->load_meta(@recordings);
    if ($c->user_exists) {
        $c->model('Recording')->rating->load_user_ratings($c->user->id, @recordings);
    }
    $c->model('ArtistCredit')->load($release, @tracks);

    my @lists;
    my %containment;
    if ($c->user_exists) {
        # Make a list of lists and whether this release is contained in them
        @lists = $c->model('List')->find_all_by_editor($c->user->id);

        foreach my $list (@lists) {
            $containment{$list->id} = 1
                if ($c->model('List')->check_release($list->id, $release->id));
        }
    }

    $c->stash(
        lists       => \@lists,
        containment => \%containment,
        template     => 'release/index.tt',
        show_artists => $release->has_multiple_artists,
    );
}

=head2 show

Lookup a CD

Given a TOC, carry out a fuzzy TOC lookup and display the matches in a table

=cut

sub medium_sort
{
    ($a->medium->format_id || 99) <=> ($b->medium->format_id || 99)
        or
    ($a->medium->release->release_group->type_id || 99) <=> ($b->medium->release->release_group->type_id || 99)
        or
    ($a->medium->release->status_id || 99) <=> ($b->medium->release->status_id || 99)
        or
    ($a->medium->release->date->year || 9999) <=> ($b->medium->release->date->year || 9999)
        or
    ($a->medium->release->date->month || 12) <=> ($b->medium->release->date->month || 12)
        or
    ($a->medium->release->date->day || 31) <=> ($b->medium->release->date->day || 31)
}

sub lookup : Local
{
    my ($self, $c) = @_;

    my $toc = $c->req->query_params->{toc};
    $c->stash->{toc} = $toc;

    my $results = $c->model('DurationLookup')->lookup($toc, DURATION_LOOKUP_RANGE);
    if (defined $results)
    {
        $c->model('Release')->load(map { $_->medium } @{$results});
        if (scalar(@{$results}) == 1)
        {
             $c->response->redirect($c->uri_for("/release/" . $results->[0]->medium->release->gid));
        }
        else
        {
            $c->model('ReleaseGroup')->load(map { $_->medium->release } @{$results});
            $c->model('ReleaseGroupType')->load(map { $_->medium->release->release_group } @{$results});
            $c->model('ReleaseStatus')->load(map { $_->medium->release } @{$results});
            $c->model('MediumFormat')->load(map { $_->medium } @{$results});
            $c->model('ArtistCredit')->load(map { $_->medium->release } @{$results});
            my @sorted = sort medium_sort @{$results};
            $c->stash->{results} = \@sorted;
        }
    }
    else
    {
        $c->stash->{results} = [];
    }
}

=head2 duplicate

Duplicate a release into the add release editor

=cut

sub duplicate : Chained('load')
{
    my ($self, $c) = @_;
    $c->forward('/user/login');
    $c->forward('_load_related');
    $c->forward('/release_editor/duplicate_release');
}

sub _load_related : Private
{
    my ($self, $c) = @_;

    my $release = $self->entity;
    $c->stash->{artist}         = $c->model('Artist')->load($release->artist);
    $c->stash->{tracks}         = $c->model('Track')->load_from_release($release);
    $c->stash->{release_events} = $c->model('Release')->load_events($release, country_id => 1);
}

=head2 rating

Rate a release

=cut

sub rating : Chained('load') Args(2)
{
    my ($self, $c, $entity, $new_vote) = @_;
    #Need more validation here

    $c->forward('/user/login');
    $c->forward('/rating/do_rating', ['artist', $entity, $new_vote]);
    $c->response->redirect($c->entity_url($self->entity, 'show'));
}

sub change_quality : Chained('load') PathPart('change-quality') RequireAuthu
{
    my ($self, $c) = @_;
    my $release = $c->stash->{release};
    $self->edit_action(
        $c,
        item => $release,
        form => 'ChangeReleaseQuality',
        type => $EDIT_RELEASE_CHANGE_QUALITY,
        edit_args => { to_edit => $release },
        on_creation => sub {
            my $uri = $c->uri_for_action('/release/show', [ $release->gid ]);
            $c->response->redirect($uri);
        }
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT

Copyright (C) 2010 MetaBrainz Foundation

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 675 Mass Ave, Cambridge, MA 02139, USA.

=cut
