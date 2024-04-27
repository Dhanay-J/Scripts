javascript: (() => { 
  var audioCtx = new (window.AudioContext || window.webkitAudioContext)();
  var videoElement = document.querySelector('video');
        if (videoElement) { 
              try { 
                    var source = audioCtx.createMediaElementSource(videoElement);
                    var gainNode = audioCtx.createGain();
                    gainNode.gain.value = 1;
                    source.connect(gainNode);
                    gainNode.connect(audioCtx.destination);
                    function boostAudio(multiplier) 
                        { 
                          if (multiplier > 0){
                              gainNode.gain.value = multiplier;  
                            }
                          else {
                              console.error("Invalid volume multiplier");
                          }
                        }
                  boostAudio(parseFloat(prompt("Set Playback Volume Gain", "1")));  
              } catch (error) {
                    console.error("Error: " + "Reload The page!");  
              } 
        } else {
          console.error("No video element found");  
        } 
})();
