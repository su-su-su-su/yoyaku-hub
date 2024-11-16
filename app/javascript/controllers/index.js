import { application } from "../controllers/application";
import HelloController from "./hello_controller.js";
application.register("hello", HelloController);
