package dk.thrane.jolie.bcrypt;

import jolie.runtime.JavaService;
import jolie.runtime.Value;
import jolie.runtime.embedding.RequestResponse;
import org.mindrot.jbcrypt.BCrypt;

public class BCryptService extends JavaService {
    @RequestResponse
    public String hashPassword(String password) {
        return BCrypt.hashpw(password, BCrypt.gensalt());
    }

    @RequestResponse
    public Boolean checkPassword(Value request) {
        String password = request.getFirstChild("password").strValue();
        String hashed = request.getFirstChild("hashed").strValue();
        return BCrypt.checkpw(password, hashed);
    }
}
