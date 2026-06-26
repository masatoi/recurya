;;;; web/ui/novel.lisp --- Novel player view (renders beats, click-to-advance).
(defpackage #:recurya/web/ui/novel
  (:use #:cl)
  (:import-from #:spinneret #:with-html-string)
  (:import-from #:recurya/utils/common #:json->string)
  (:export #:render-player))

(in-package #:recurya/web/ui/novel)

(defun %beats->json (beats)
  "Serialize BEATS (list of plists) to a JSON array string for the client."
  (json->string
   (mapcar (lambda (b)
             (let ((h (make-hash-table :test 'equal)))
               (setf (gethash "type" h) (string-downcase (symbol-name (getf b :type)))
                     (gethash "speaker" h) (or (getf b :speaker) "")
                     (gethash "text" h) (or (getf b :text) "")
                     (gethash "bg" h) (or (getf b :bg) ""))
               h))
           beats)))

(defun render-player (&key title beats)
  "Render a minimal novel player page. BEATS is a list of beat plists."
  (with-html-string
    (:div :class "novel-player"
          :data-beats (%beats->json beats)
      (:div :class "novel-bg" :id "novel-bg")
      (:div :class "novel-box"
        (:div :class "novel-speaker" :id "novel-speaker")
        (:div :class "novel-text" :id "novel-text")
        (:button :type "button" :class "novel-next" :id "novel-next" "▶"))
      (:noscript (:p title))
      (:script :type "text/javascript"
        (:raw "(function(){
  var root=document.querySelector('.novel-player');
  var beats=JSON.parse(root.getAttribute('data-beats')||'[]');
  var i=-1;
  var bg=document.getElementById('novel-bg');
  var sp=document.getElementById('novel-speaker');
  var tx=document.getElementById('novel-text');
  function show(n){var b=beats[n]; if(!b){tx.textContent='— おわり —'; sp.textContent=''; return;}
    bg.setAttribute('data-bg', b.bg||'');
    sp.textContent=(b.type==='say')?(b.speaker||''):'';
    tx.textContent=b.text||'';}
  function next(){ if(i<beats.length-1){i++; show(i);} }
  document.getElementById('novel-next').addEventListener('click',next);
  document.addEventListener('keydown',function(e){if(e.key===' '||e.key==='Enter'){e.preventDefault();next();}});
  next();
})();")))))
