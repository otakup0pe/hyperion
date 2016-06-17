all: test

test:
	xmllint plugin/*.xml 1> /dev/null
	cd plugin && lua *.lua
	./scripts/check-json
