# Print "address<TAB>label" for every open window, grouped by workspace
import json, subprocess

clients = json.loads(subprocess.run(["hyprctl", "-j", "clients"], capture_output=True, text=True).stdout)
wins = [w for w in clients if w["mapped"] and w["workspace"]["id"] > 0]
for w in sorted(wins, key=lambda w: (w["workspace"]["id"], w["focusHistoryID"])):
    title = (w["title"] or w["class"])[:60]
    print(f'{w["address"]}\t {w["workspace"]["id"]}   {w["class"]}  —  {title}')
