/*
 * @flow
 * Copyright (C) 2019 Anirudh Jain
 *
 * This file is part of MusicBrainz, the open internet music database,
 * and is licensed under the GPL version 2, or (at your option) any
 * later version: http://www.gnu.org/licenses/gpl-2.0.txt
 */

import React from 'react';

import DescriptiveLink from
  '../../static/scripts/common/components/DescriptiveLink';
import Diff from '../../static/scripts/edit/components/edit/Diff';
import FullChangeDiff from
  '../../static/scripts/edit/components/edit/FullChangeDiff';
import {formatCoordinates} from '../../utility/coordinates';
import formatDate from '../../static/scripts/common/utility/formatDate';
import yesNo from '../../static/scripts/common/utility/yesNo';

type PlaceEditT = {
  ...EditT,
  +display_data: {
    +address?: CompT<string>,
    +area?: CompT<AreaT | null>,
    +begin_date?: CompT<PartialDateT>,
    +comment?: CompT<string>,
    +coordinates?: CompT<CoordinatesT | null>,
    +end_date?: CompT<PartialDateT>,
    +ended?: CompT<boolean>,
    +name: CompT<string>,
    +place: PlaceT,
    +type?: CompT<PlaceTypeT | null>,
  },
};

const EditPlace = ({edit}: {edit: PlaceEditT}) => {
  const display = edit.display_data;
  const address = display.address;
  const area = display.area;
  const beginDate = display.begin_date;
  const comment = display.comment;
  const coordinates = display.coordinates;
  const endDate = display.end_date;
  const ended = display.ended;
  const place = display.place;
  const oldTypeName = display.type?.old?.name ?? '';
  const newTypeName = display.type?.new?.name ?? '';
  return (
    <table className="details edit-place">
      <tbody>
        <tr>
          <th>{addColonText(l('Place'))}</th>
          <td><DescriptiveLink entity={place} /></td>
        </tr>
        {display.name ? (
          <Diff
            label={addColonText(l('Name'))}
            newText={display.name.new}
            oldText={display.name.old}
            split="\s+"
          />
        ) : null}
        {comment ? (
          <Diff
            label={addColonText(l('Disambiguation'))}
            newText={comment.new}
            oldText={comment.old}
            split="\s+"
          />
        ) : null}
        {display.type ? (
          <FullChangeDiff
            label={addColonText(l('Type'))}
            newContent={newTypeName ? lp_attributes(newTypeName,
                                                    'place_type') : ''}
            oldContent={oldTypeName ? lp_attributes(oldTypeName,
                                                    'place_type') : ''}
          />
        ) : null}
        {address ? (
          <Diff
            label={addColonText(l('Address'))}
            newText={address.new}
            oldText={address.old}
            split="\s+"
          />
        ) : null}
        {area && area.new?.gid !== area.old?.gid ? (
          <FullChangeDiff
            label={addColonText(l('Area'))}
            newContent={area.new
              ? <DescriptiveLink entity={area.new} />
              : ''}
            oldContent={area.old
              ? <DescriptiveLink entity={area.old} />
              : ''}
          />
        ) : null}
        {coordinates ? (
          <Diff
            label={addColonText(l('Coordinates'))}
            newText={formatCoordinates(coordinates.new)}
            oldText={formatCoordinates(coordinates.old)}
          />
        ) : null}
        {beginDate ? (
          <Diff
            label={addColonText(l('Begin date'))}
            newText={formatDate(beginDate.new)}
            oldText={formatDate(beginDate.old)}
            split="-"
          />
        ) : null}
        {endDate ? (
          <Diff
            label={addColonText(l('End date'))}
            newText={formatDate(endDate.new)}
            oldText={formatDate(endDate.old)}
            split="-"
          />
        ) : null}
        {ended ? (
          <FullChangeDiff
            label={addColonText(l('Ended'))}
            newContent={yesNo(ended.new)}
            oldContent={yesNo(ended.old)}
          />
        ) : null}
      </tbody>
    </table>
  );
};

export default EditPlace;
