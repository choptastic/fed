install:
	./install.sh

screen:
	echo 'bind "^e" eval "screen fed --screen_prompt"' >> ~/.screenrc
