javascript:(() => {  
const newPlaybackSpeed = parseFloat(prompt("Set Playback Speed", "1"));
  if (!isNaN(newPlaybackSpeed) && newPlaybackSpeed > 0) {
      const videoElement = document.querySelector('video');    
          if (videoElement) {
                  videoElement.playbackRate = newPlaybackSpeed;
                  alert(`Playback speed set to ${newPlaybackSpeed}`);
          } else {
                  alert("No video element found on the page.");
          }
  }   else  {
         alert("Invalid playback speed input.");  
    }
}
)();
