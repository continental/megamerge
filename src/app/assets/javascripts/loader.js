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

var loadingCnt =0;

function ChangeLoadingCnt(cnt) {
  var oldLoadingCnt = loadingCnt;
  loadingCnt+=cnt;

  if(loadingCnt==0 && oldLoadingCnt == 1)
    FadeInputs(true);

  if(loadingCnt==1 && oldLoadingCnt == 0)
    FadeInputs(false);
}

function FadeInputs(fadeIn) {

  if(fadeIn) {
    $('#disableInputsDivOverlay').fadeTo('fast',0).promise().done(function() {
      $('#disableInputsDivOverlay').hide();
    });
  } else {
    $('#disableInputsDivOverlay').show();
    $('#disableInputsDivOverlay').fadeTo('fast',1);
  }
}
