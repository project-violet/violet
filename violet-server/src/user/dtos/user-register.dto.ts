import { IsString, Matches } from 'class-validator';

export class UserRegisterDTO {
  @IsString()
  @Matches(/^\w{40}$/, {
    message:
      'Id must be between 4 and 20 characters long with number or alphabet',
  })
  userAppId: string;

  // @IsString()
  // @Matches(/^(?=.*\d)(?=.*[a-z])(?=.*[A-Z])(?=.*[!@#$%^&+=]).{6,64}$/, {
  //   message:
  //     'Password must be between 6 and 64 characters long with 1 special character and capital character each',
  // })
  // password: string;
}
