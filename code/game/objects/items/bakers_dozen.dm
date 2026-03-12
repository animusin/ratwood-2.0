/*
 * BAKER'S DOZEN
 * A blackjack-style d6 game for 1-4 players where the target is 13.
 *
 * Rules:
 * - Each player must roll 2d6 (one die at a time).
 * - After the two mandatory rolls, players may either roll one d6 (hit) or stay.
 * - Going over 13 is an immediate bust.
 * - Round ends when every player has stayed, hit exactly 13, or busted.
 * - Highest non-bust total wins.
 * - If top totals tie, tied players repeatedly roll one extra d6 each until one is highest.
 */

/datum/bakers_dozen_game
	var/list/mob/living/players = list()
	var/list/scores = list() // assoc: mob -> current total
	var/list/mandatory_rolls = list() // assoc: mob -> number of required opening rolls completed
	var/list/stayed = list() // assoc: mob -> TRUE/FALSE
	var/list/busted = list() // assoc: mob -> TRUE/FALSE
	var/current_player_index = 0
	var/target_score = 13
	var/obj/item/storage/pill_bottle/dice/bakers_dozen/game_bag
	var/busy = FALSE
	var/joining = TRUE
	var/max_players = 4

/datum/bakers_dozen_game/proc/try_join(mob/living/joiner)
	if(!joiner || !joiner.client)
		return
	if(!joining)
		to_chat(joiner, span_warning("The Baker's Dozen game has already started."))
		return

	if(joiner in players)
		var/list/opts = list("Leave game")
		if(players.len >= 2)
			opts += "Start game now"
		var/choice = input(joiner, "You are already in the lobby. ([players.len]/[max_players] players)", "Baker's Dozen") as null|anything in opts
		if(choice == "Start game now")
			start_game()
		else if(choice == "Leave game")
			players -= joiner
			game_bag.visible_message(span_notice("[joiner] left the pre-game lobby. ([players.len]/[max_players])"))
			if(!players.len)
				cancel_game(joiner)
		return

	if(players.len >= max_players)
		to_chat(joiner, span_warning("The Baker's Dozen game is full ([max_players]/[max_players])."))
		return

	players += joiner
	game_bag.visible_message(span_notice("[joiner] joined Baker's Dozen! ([players.len]/[max_players] players)"))
	if(players.len >= max_players)
		start_game()

/datum/bakers_dozen_game/proc/cancel_game(mob/living/canceller)
	game_bag.visible_message(span_warning("[canceller] has cancelled Baker's Dozen!"))
	game_bag.active_game = null
	qdel(src)

/datum/bakers_dozen_game/proc/start_game()
	joining = FALSE
	for(var/mob/living/M in players)
		scores[M] = 0
		mandatory_rolls[M] = 0
		stayed[M] = FALSE
		busted[M] = FALSE

	var/list/names = list()
	for(var/mob/living/M in players)
		names += "[M]"
	game_bag.visible_message(span_notice("Baker's Dozen begins! Target: [target_score]. Players: [jointext(names, ", ")]."))
	next_turn()

/datum/bakers_dozen_game/proc/player_is_done(mob/living/M)
	if(!M)
		return TRUE
	if(busted[M])
		return TRUE
	if(stayed[M])
		return TRUE
	if(scores[M] >= target_score)
		return TRUE
	return FALSE

/datum/bakers_dozen_game/proc/all_players_done()
	for(var/mob/living/M in players)
		if(!M.client)
			stayed[M] = TRUE
		if(!player_is_done(M))
			return FALSE
	return TRUE

/datum/bakers_dozen_game/proc/next_turn()
	if(all_players_done())
		end_round()
		return

	var/attempts = 0
	while(attempts < players.len)
		current_player_index++
		if(current_player_index > players.len)
			current_player_index = 1

		var/mob/living/active = players[current_player_index]
		if(!active || !active.client)
			stayed[active] = TRUE
			attempts++
			continue
		if(player_is_done(active))
			attempts++
			continue

		game_bag.visible_message(span_notice("--- [active]'s turn | [get_score_display()] ---"))
		if(mandatory_rolls[active] < 2)
			to_chat(active, span_notice("Opening phase: rolling your two mandatory d6 automatically."))
			do_opening_rolls(active)
		else
			to_chat(active, span_notice("Choose to roll 1d6 or stay. Target: [target_score]."))
		return

	end_round()

/datum/bakers_dozen_game/proc/player_action(mob/living/user)
	if(!(user in players))
		to_chat(user, span_notice("Current totals: [get_score_display()]"))
		return

	if(busy)
		to_chat(user, span_notice("Please wait a moment..."))
		return

	if(user != players[current_player_index])
		input(user, "It's not your turn. Totals: [get_score_display()]", "Baker's Dozen") as null|anything in list("OK")
		return

	if(player_is_done(user))
		to_chat(user, span_notice("You're done for this round. Totals: [get_score_display()]"))
		next_turn()
		return

	if(mandatory_rolls[user] < 2)
		to_chat(user, span_notice("Opening rolls are automatic. Wait for your opening turn to resolve."))
		return

	var/decision = input(user, "Your total: [scores[user]] / [target_score]\nWhat do you do?", "Baker's Dozen") as null|anything in list("Hit - roll 1d6", "Stay")
	if(decision == "Stay" || !decision)
		stayed[user] = TRUE
		game_bag.visible_message(span_notice("[user] stays at [scores[user]]."))
		if(all_players_done())
			end_round()
		else
			next_turn()
		return

	do_roll(user, FALSE)

/datum/bakers_dozen_game/proc/do_opening_rolls(mob/living/active)
	while(mandatory_rolls[active] < 2 && !busted[active] && scores[active] < target_score)
		do_roll(active, TRUE, FALSE)
		if(all_players_done())
			break

	if(all_players_done())
		end_round()
	else
		next_turn()

/datum/bakers_dozen_game/proc/do_roll(mob/living/active, mandatory = FALSE, advance_turn = TRUE)
	busy = TRUE
	playsound(game_bag, 'sound/items/cup_dice_roll.ogg', 75, TRUE)

	var/roll = rand(1, 6)
	var/old_total = scores[active]
	scores[active] = old_total + roll
	if(mandatory)
		mandatory_rolls[active]++

	game_bag.visible_message(span_notice("[active] rolls [roll]! Total: [scores[active]] / [target_score]."))

	if(scores[active] > target_score)
		busted[active] = TRUE
		game_bag.visible_message(span_danger("[active] busts at [scores[active]]!"))
	else if(scores[active] == target_score)
		game_bag.visible_message(span_notice("[active] hit BAKER'S DOZEN exactly!"))

	busy = FALSE

	if(!advance_turn)
		return

	if(all_players_done())
		end_round()
	else
		next_turn()

/datum/bakers_dozen_game/proc/end_round()
	var/list/contenders = list()
	var/best_total = -1

	for(var/mob/living/M in players)
		if(busted[M])
			continue
		var/total = scores[M]
		if(total > best_total)
			best_total = total
			contenders = list(M)
		else if(total == best_total)
			contenders += M

	game_bag.visible_message(span_notice("--- BAKER'S DOZEN ROUND OVER --- Totals: [get_score_display()]"))

	if(!contenders.len)
		game_bag.visible_message(span_warning("Everyone busted. No winner this round."))
		game_bag.active_game = null
		qdel(src)
		return

	if(contenders.len == 1)
		var/mob/living/champion = contenders[1]
		game_bag.visible_message(span_notice("[champion] wins with [scores[champion]]!"))
		game_bag.active_game = null
		qdel(src)
		return

	tie_break(contenders)

/datum/bakers_dozen_game/proc/tie_break(list/mob/living/contenders)
	while(contenders.len > 1)
		var/list/names = list()
		for(var/mob/living/M in contenders)
			names += "[M]"
		game_bag.visible_message(span_warning("Tie at [scores[contenders[1]]] between [jointext(names, ", ")]! Tie-break roll!"))

		var/list/new_contenders = list()
		var/best_total = -1
		for(var/mob/living/M in contenders)
			if(!M.client)
				continue
			var/roll = rand(1, 6)
			scores[M] += roll
			game_bag.visible_message(span_notice("[M] tie-break rolls [roll] -> [scores[M]] total."))
			if(scores[M] > best_total)
				best_total = scores[M]
				new_contenders = list(M)
			else if(scores[M] == best_total)
				new_contenders += M

		if(!new_contenders.len)
			game_bag.visible_message(span_warning("Tie-break ended with no active contenders."))
			game_bag.active_game = null
			qdel(src)
			return

		contenders = new_contenders

	var/mob/living/champion = contenders[1]
	game_bag.visible_message(span_notice("[champion] wins Baker's Dozen with [scores[champion]]!"))
	game_bag.active_game = null
	qdel(src)

/datum/bakers_dozen_game/proc/get_score_display()
	var/list/parts = list()
	for(var/mob/living/M in players)
		var/state = ""
		if(busted[M])
			state = " (BUST)"
		else if(stayed[M])
			state = " (STAY)"
		else if(scores[M] == target_score)
			state = " (BAKER'S DOZEN)"
		parts += "[M]: [scores[M]][state]"
	return jointext(parts, " | ")

/obj/item/storage/pill_bottle/dice/bakers_dozen
	name = "bag of baker's dozen dice"
	desc = "A set of dice for Baker's Dozen. Activate in hand (Z) to start or join a game."
	var/datum/bakers_dozen_game/active_game
	var/static/bakers_dozen_rules_text = {"<div style='padding:8px;font-family:Verdana,sans-serif;'>
- Each player rolls a d6 dice twice.<br>
- After every player has rolled twice, players may only roll a single d6 or stay until the next round.<br>
- The goal is to get as close to, or exactly 13 which is a baker's dozen. Going over means you lose immediately.<br>
- The round does not end until all players stay or hit 13, or bust.<br>
- If two players end up with a tie, they do a final round to tie break with one more dice roll.<br>
- Whoever gets the highest total wins. If it ties again, they repeat until a winner is found.
</div>"}

/obj/item/storage/pill_bottle/dice/bakers_dozen/proc/show_rules(mob/living/user)
	if(!user)
		return
	user << browse(bakers_dozen_rules_text, "window=bakers_dozen_rules;size=700x450")

/obj/item/storage/pill_bottle/dice/bakers_dozen/PopulateContents()
	for(var/i in 1 to 6)
		new /obj/item/dice/d6(src)

/obj/item/storage/pill_bottle/dice/bakers_dozen/attack_self(mob/living/user)
	var/choice = input(user, "Select an option.", "Baker's Dozen Dice") as null|anything in list(
		"Start Game",
		"Hit - roll 1d6",
		" ",
		"Rules",
		"  ",
		"Cancel Game",
		"   ",
		"End Game"
	)

	if(!choice)
		return

	if(choice == "Rules")
		show_rules(user)
		return

	if(choice == "Cancel Game")
		if(active_game && active_game.joining)
			active_game.cancel_game(user)
		else if(active_game)
			to_chat(user, span_notice("Cancel Game is only available before the game starts. Use End Game once a game is in progress."))
		else
			to_chat(user, span_notice("No Baker's Dozen game is currently running."))
		return

	if(choice == "End Game")
		if(active_game)
			active_game.cancel_game(user)
		else
			to_chat(user, span_notice("No Baker's Dozen game is currently running."))
		return

	if(choice == "Hit - roll 1d6")
		if(!active_game)
			to_chat(user, span_notice("No Baker's Dozen game is currently running."))
			return
		if(active_game.joining)
			active_game.try_join(user)
		else
			active_game.player_action(user)
		return

	if(choice != "Start Game")
		return

	if(!active_game)
		var/count = input(user, "How many players?\n(2 to 4 players)", "Baker's Dozen") as null|anything in list(2, 3, 4)
		if(!count)
			return

		var/datum/bakers_dozen_game/new_game = new()
		new_game.game_bag = src
		new_game.max_players = count
		active_game = new_game
		new_game.try_join(user)

		src.visible_message(span_notice("[user] is starting Baker's Dozen! [count - 1] more player(s) needed. Activate (Z) the dice bag to join!"))
		return

	if(active_game.joining)
		active_game.try_join(user)
	else
		active_game.player_action(user)
