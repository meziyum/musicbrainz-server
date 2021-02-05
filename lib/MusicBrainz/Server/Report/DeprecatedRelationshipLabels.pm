package MusicBrainz::Server::Report::DeprecatedRelationshipLabels;
use Moose;

with 'MusicBrainz::Server::Report::LabelReport',
     'MusicBrainz::Server::Report::FilterForEditor::LabelID',
     'MusicBrainz::Server::Report::DeprecatedRelationshipReport';

sub entity_type { 'label' }

__PACKAGE__->meta->make_immutable;
no Moose;
1;

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2013 MetaBrainz Foundation

This file is part of MusicBrainz, the open internet music database,
and is licensed under the GPL version 2, or (at your option) any
later version: http://www.gnu.org/licenses/gpl-2.0.txt

=cut
