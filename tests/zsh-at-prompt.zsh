# zsh-at-prompt.zsh RC DIR INPUT: start an interactive zsh (no rc files) on a
# pseudo-terminal, source RC, cd to DIR, type INPUT at the prompt, then print
# the directory it ended up in. Some behaviour, like AUTO_CD, only applies to
# commands typed at a real prompt, so `zsh -c` can't test it.
zmodload zsh/zpty
zpty -b z zsh -f -i
zpty -w z "PS1='> '; source ${(q)1}; cd ${(q)2}"
zpty -w z "$3"
zpty -w z 'print -r -- "PWD=$PWD"'

local out line tries=0
while (( tries++ < 100 )); do
  if zpty -r -t z line 2>/dev/null; then
    out+=$line
    [[ $line == *PWD=/* ]] && break
  else
    sleep 0.05
  fi
done
zpty -d z
[[ $out == *PWD=/* ]] || { print -u2 "no prompt output"; exit 1 }
print -r -- ${${out##*PWD=}%%$'\r'*}
