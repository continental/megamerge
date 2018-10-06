/* Copyright (c) 2018 Continental Automotive GmbH
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

function UpdateSaveAbleButton() {
  var saveAble = true;

  $('input[id^="saveAble"]').each(function(){
    if($(this).val() == "false")
      saveAble = false;
  });

  $("#saveChangesButton").prop('disabled', !saveAble);
}


function ChangeWasDone() {
  $('#saveChangesButton').fadeTo('slow',1);
  $('#performMegaMergeButton').hide();
  UpdateSaveAbleButton();
}


$(document).ready(function() {

  if (typeof pr_id === 'undefined')
    return;

  // save button only visible if this is a new MM-PR
  if(pr_id == 0 || pr_outdated)
    $('#saveChangesButton').show();
  else
    $('#saveChangesButton').hide();

});
