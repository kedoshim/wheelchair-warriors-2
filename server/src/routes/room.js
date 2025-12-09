import express from "express";
import { RouterController } from "../controllers/rooms.js";


const router = express.Router();

router.post("/create", RouterController.createRoom);
router.get('/list', RouterController.listAllRooms)

export default router;
