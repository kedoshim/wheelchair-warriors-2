import { client } from "../database/client.js";

export class RouterController {
    static async createRoom(req, res) {
        let roomInfo = {

        }
        roomInfo['creator_username'] = req.body.username
        roomInfo['active_players'] = [req.body.username]
    }
}