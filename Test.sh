echo "## UNITTEST ######################################"
dub test
echo "## JSON     ######################################"
dub -- -tmpl test.tmpl test.json -copy other
echo "## PROTO    ######################################"
dub -- -tmpl testa.tmpl test.proto -copy other