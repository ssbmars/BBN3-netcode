# boomsheetslua
This is a lua port of the boomsheet animation file format for 2D spritesheets

## Example
```lua
anim = boom.load(path)        -- loads the animation from path and stores it in the anim table
t    = anim:duration(state)   -- returns the duration of the animation state in seconds
f    = anim:refresh(state)    --  sets `elapsed` to zero and applies the first frame from that state
f    = anim:update(state,sec) -- updates animation by seconds elapsed and returns the frame

print(anim.imagePath) -- prints the image path
print(anim.elapsed)   -- the elapsed time for this animation
curr = anim.currFrame -- can also access the current frame this way

anim.states.ATTACK_PUNCH.loop = true -- tells this animation state to loop (default false)
```