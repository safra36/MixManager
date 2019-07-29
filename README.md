# MixManager

## Description
A Simple PUG plugin allow you to host your own tournaments fulfilling the most simple requirements for a tournament.

## Admin Commands
- All Admin Commands require you to have admin flag 'KICK'
- sm_live 
Allow you to make the match live without needing everyone to become ready.
- sm_warmup
This will put the match in warmup which means it will cancel the current match if it's live already.
- sm_talk 1/0
This will allow you to enable or disable full alltalk
- sm_swap
Swap teams with this command
- sm_bkick
Kick all fake clients ingame
- sm_team #userid/@all #CT/T/SPEC
Change a user or everyone's team
- sm_password #Password
Change server's password.
- sm_r1
Restart the match


## Commands
- These commands are avaialble for everyone on the server
- sm_pause
Request pause for your team the number needed to actually get the match paused will be decleared in a convar below
- sm_unpause
Currently this only works for an admin but will manage to make it work for clients as well.
- sm_ready
Ready up for the match
- sm_unready
Unready for the match


## ConVars
- These convars are here to let you control stuff in your server cfg files
- mm_pause_time 60.0
When a team request pause the timer will be this number in float
- mm_can_pause 1
If 1 then !pause will be allowed.
- mm_pause_max_users 3
Max numbe rof useres per team needed to request for a pause
- mm_ready_system 1
Whether to use the ready system or not
- mm_ready_max 10
Max number of users needed to be ready inorder for the match to begin
- mm_show_weapons 1
If enabled, each freezetime teammates will be notified of their other teammates weapon purchases
- mm_knife_round_enable 1
If this is enabled, the first round of the match will be a knife round to choose sides



## Notes
If you used knife round be aware that after a team wins they must type Stay or Swap in the chat in order for the match to continue.





## Contact me @ steam using https://steamcommunity.com/id/ammoba

