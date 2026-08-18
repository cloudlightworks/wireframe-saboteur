extends Node
# Per-install identity for replay records.
#
# The id is generated once and never changes: it is what a future ranking system
# would key on, since display names are free text and change every match.
# The keypair exists so a player can sign their own records. Signing does not
# prevent fabrication — it binds a fabrication to an identity, which is what
# makes a contradiction between two players' records detectable.
#
# Nothing here is authoritative and nothing gameplay reads it.

const KEY_PATH := "user://player_key.pem"

var player_id: String = ""
var _crypto: Crypto = null
var _key: CryptoKey = null

func _ready() -> void:
	_crypto = Crypto.new()
	_load_or_create_key()
	# Derived from the public key, not independent randomness: an id that isn't
	# a fingerprint of its own key could be copied from someone else's record
	# and claimed. This way a mismatch between id and pubkey is self-evident.
	player_id = public_key_pem().sha256_text().substr(0, 32)

func _load_or_create_key() -> void:
	if FileAccess.file_exists(KEY_PATH):
		_key = CryptoKey.new()
		if _key.load(KEY_PATH) == OK:
			return
		_key = null
	# 2048 is plenty here and keeps first-launch generation quick.
	_key = _crypto.generate_rsa(2048)
	_key.save(KEY_PATH)

func public_key_pem() -> String:
	if _key == null:
		return ""
	return _key.save_to_string(true)   # true = public part only

func sign_text(text: String) -> String:
	if _key == null:
		return ""
	var digest := text.sha256_buffer()
	return _crypto.sign(HashingContext.HASH_SHA256, digest, _key).hex_encode()
