import { Body, Controller, HttpCode, HttpStatus, Patch, Post, UseGuards } from '@nestjs/common';
import { AuthService } from './auth.service';
import { RegisterDto } from './dto/register.dto';
import { RefreshTokenDto } from './dto/refresh-token.dto';
import { GoogleAuthDto } from './dto/google-auth.dto';
import { ForgotPasswordDto } from './dto/forgot-password.dto';
import { ResetPasswordDto } from './dto/reset-password.dto';
import { ChangePasswordDto } from './dto/change-password.dto';
import { LocalAuthGuard } from './guards/local-auth.guard';
import { Public } from '../../common/decorators/public.decorator';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import { User } from '../users/user.entity';

@Controller('auth')
export class AuthController {
  constructor(private authService: AuthService) {}

  @Public()
  @Post('register')
  @HttpCode(HttpStatus.CREATED)
  register(@Body() dto: RegisterDto) {
    return this.authService.register(dto);
  }

  @Public()
  @UseGuards(LocalAuthGuard)
  @Post('login')
  @HttpCode(HttpStatus.OK)
  login(@CurrentUser() user: User) {
    return this.authService.login(user);
  }

  @Public()
  @Post('refresh')
  @HttpCode(HttpStatus.OK)
  refresh(@Body() dto: RefreshTokenDto) {
    return this.authService.refresh(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  logout(@Body() dto: RefreshTokenDto) {
    return this.authService.logout(dto.refreshToken);
  }

  @Public()
  @Post('google')
  @HttpCode(HttpStatus.OK)
  googleLogin(@Body() dto: GoogleAuthDto) {
    return this.authService.googleLogin(dto.idToken);
  }

  @Public()
  @Post('forgot-password')
  @HttpCode(HttpStatus.ACCEPTED)
  async forgotPassword(@Body() dto: ForgotPasswordDto) {
    await this.authService.requestPasswordReset(dto.email);
    return {
      message: 'Si la cuenta permite contraseña, recibirás instrucciones por correo.',
    };
  }

  @Public()
  @Post('reset-password')
  @HttpCode(HttpStatus.NO_CONTENT)
  async resetPassword(@Body() dto: ResetPasswordDto): Promise<void> {
    await this.authService.resetPassword(dto.token, dto.password);
  }

  @Patch('password')
  @HttpCode(HttpStatus.NO_CONTENT)
  changePassword(@CurrentUser() user: User, @Body() dto: ChangePasswordDto): Promise<void> {
    return this.authService.changePassword(user.id, dto.currentPassword, dto.newPassword);
  }
}
